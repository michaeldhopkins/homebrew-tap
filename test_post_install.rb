#!/usr/bin/env ruby
# frozen_string_literal: true

require "tmpdir"
require "json"
require "pathname"

# Stubs for Homebrew helpers
module BrewStubs
  def ohai(msg)
    @output << "==> #{msg}"
  end

  def opoo(msg)
    @output << "Warning: #{msg}"
  end
end

# Testable extraction of the formula's post_install logic.
# The methods mirror safe-chains.rb but accept injectable paths.
class PostInstallHarness
  include BrewStubs

  attr_reader :output

  def initialize(home_dir:, opencode_in_path:, share_dir: "/opt/homebrew/share")
    @home_dir = Pathname.new(home_dir)
    @opencode_in_path = opencode_in_path
    @share_dir = share_dir
    @binary_path = "/opt/homebrew/bin/safe-chains"
    @homepage = "https://github.com/michaeldhopkins/safe-chains"
    @output = []
  end

  def run
    configured = []

    claude_dir = @home_dir/".claude"
    configure_claude_code(claude_dir, @binary_path, configured) if claude_dir.exist?

    configured.each { |msg| ohai msg }

    if @opencode_in_path
      ohai "OpenCode detected — copy the plugin to each project:"
      @output << "  cp #{@share_dir}/safe-chains/opencode-plugin.js .opencode/plugins/"
    end

    if configured.empty? && !@opencode_in_path
      ohai "safe-chains installed. Configure it for your agentic tool:"
      @output << "  Claude Code: #{@homepage}#claude-code"
      @output << "  OpenCode:    cp #{@share_dir}/safe-chains/opencode-plugin.js .opencode/plugins/"
    end

    opoo "safe-chains will check every Bash command before your agentic tool runs it"
  end

  def settings_content
    path = @home_dir/".claude"/"settings.json"
    return nil unless path.exist?

    JSON.parse(path.read)
  rescue JSON::ParserError
    :malformed
  end

  private

  def configure_claude_code(claude_dir, binary_path, configured)
    settings_path = claude_dir/"settings.json"

    hook_entry = {
      "matcher" => "Bash",
      "hooks" => [{
        "type" => "command",
        "command" => binary_path,
      }],
    }

    if settings_path.exist?
      settings = JSON.parse(settings_path.read)
      pre_tool_use = settings.dig("hooks", "PreToolUse") || []
      if pre_tool_use.any? { |h| h["hooks"]&.any? { |inner| inner["command"]&.include?("safe-chains") } }
        configured << "safe-chains hook already configured in ~/.claude/settings.json"
        return
      end
      settings["hooks"] ||= {}
      settings["hooks"]["PreToolUse"] ||= []
      settings["hooks"]["PreToolUse"] << hook_entry
    else
      settings = { "hooks" => { "PreToolUse" => [hook_entry] } }
    end

    settings_path.write(JSON.pretty_generate(settings) + "\n")
    configured << "safe-chains hook added to ~/.claude/settings.json"
  rescue JSON::ParserError
    opoo "Could not parse ~/.claude/settings.json; skipping hook installation."
    opoo "See: #{@homepage}#claude-code"
  end
end

# --- Test runner ---

pass = 0
fail = 0

def assert(description, condition)
  if condition
    puts "  PASS: #{description}"
    true
  else
    puts "  FAIL: #{description}"
    false
  end
end

def run_scenario(name, home_dir:, opencode:, setup: nil)
  puts "\n--- #{name} ---"
  setup&.call(home_dir)
  harness = PostInstallHarness.new(home_dir: home_dir, opencode_in_path: opencode)
  harness.run
  [harness, harness.output, harness.settings_content]
end

# Scenario 1: No ~/.claude, no opencode
Dir.mktmpdir do |tmpdir|
  harness, output, settings = run_scenario(
    "No ~/.claude, no opencode",
    home_dir: tmpdir, opencode: false,
  )
  pass += 1 if assert("no settings.json created", settings.nil?)
  pass += 1 if assert("no ~/.claude dir created", !Pathname.new(tmpdir).join(".claude").exist?)
  pass += 1 if assert("prints generic instructions", output.any? { |l| l.include?("Configure it for your agentic tool") })
  pass += 1 if assert("mentions Claude Code", output.any? { |l| l.include?("Claude Code:") })
  pass += 1 if assert("mentions OpenCode", output.any? { |l| l.include?("OpenCode:") })
  pass += 1 if assert("prints opoo", output.any? { |l| l.include?("will check every Bash command") })
  fail += (6 - [settings.nil?, !Pathname.new(tmpdir).join(".claude").exist?,
    output.any? { |l| l.include?("Configure it for your agentic tool") },
    output.any? { |l| l.include?("Claude Code:") },
    output.any? { |l| l.include?("OpenCode:") },
    output.any? { |l| l.include?("will check every Bash command") }].count(true))
end

# Scenario 2: ~/.claude exists, no settings.json
Dir.mktmpdir do |tmpdir|
  harness, output, settings = run_scenario(
    "~/.claude exists, no settings.json",
    home_dir: tmpdir, opencode: false,
    setup: ->(d) { Pathname.new(d).join(".claude").mkpath },
  )
  pass += 1 if assert("settings.json created", !settings.nil?)
  pass += 1 if assert("hook present in settings", settings&.dig("hooks", "PreToolUse")&.any? { |h| h["hooks"]&.any? { |i| i["command"]&.include?("safe-chains") } })
  pass += 1 if assert("prints 'hook added'", output.any? { |l| l.include?("hook added") })
  fail += (3 - [!settings.nil?,
    settings&.dig("hooks", "PreToolUse")&.any? { |h| h["hooks"]&.any? { |i| i["command"]&.include?("safe-chains") } },
    output.any? { |l| l.include?("hook added") }].count(true))
end

# Scenario 3: ~/.claude with empty settings.json
Dir.mktmpdir do |tmpdir|
  harness, output, settings = run_scenario(
    "~/.claude with empty settings.json",
    home_dir: tmpdir, opencode: false,
    setup: lambda { |d|
      claude = Pathname.new(d).join(".claude")
      claude.mkpath
      (claude/"settings.json").write("{}\n")
    },
  )
  pass += 1 if assert("hook added to settings", settings&.dig("hooks", "PreToolUse")&.any? { |h| h["hooks"]&.any? { |i| i["command"]&.include?("safe-chains") } })
  pass += 1 if assert("prints 'hook added'", output.any? { |l| l.include?("hook added") })
  fail += (2 - [settings&.dig("hooks", "PreToolUse")&.any? { |h| h["hooks"]&.any? { |i| i["command"]&.include?("safe-chains") } },
    output.any? { |l| l.include?("hook added") }].count(true))
end

# Scenario 4: ~/.claude with existing hook
Dir.mktmpdir do |tmpdir|
  harness, output, settings = run_scenario(
    "~/.claude with existing safe-chains hook",
    home_dir: tmpdir, opencode: false,
    setup: lambda { |d|
      claude = Pathname.new(d).join(".claude")
      claude.mkpath
      existing = {
        "hooks" => {
          "PreToolUse" => [{
            "matcher" => "Bash",
            "hooks" => [{ "type" => "command", "command" => "/opt/homebrew/bin/safe-chains" }],
          }],
        },
      }
      (claude/"settings.json").write(JSON.pretty_generate(existing) + "\n")
    },
  )
  hooks = settings&.dig("hooks", "PreToolUse") || []
  pass += 1 if assert("no duplicate hook added", hooks.length == 1)
  pass += 1 if assert("prints 'already configured'", output.any? { |l| l.include?("already configured") })
  fail += (2 - [hooks.length == 1,
    output.any? { |l| l.include?("already configured") }].count(true))
end

# Scenario 5: ~/.claude with malformed JSON
Dir.mktmpdir do |tmpdir|
  harness, output, _settings = run_scenario(
    "~/.claude with malformed JSON",
    home_dir: tmpdir, opencode: false,
    setup: lambda { |d|
      claude = Pathname.new(d).join(".claude")
      claude.mkpath
      (claude/"settings.json").write("not valid json{{{")
    },
  )
  pass += 1 if assert("prints parse warning", output.any? { |l| l.include?("Could not parse") })
  pass += 1 if assert("does not print 'hook added'", output.none? { |l| l.include?("hook added") })
  fail += (2 - [output.any? { |l| l.include?("Could not parse") },
    output.none? { |l| l.include?("hook added") }].count(true))
end

# Scenario 6: OpenCode only, no ~/.claude
Dir.mktmpdir do |tmpdir|
  harness, output, settings = run_scenario(
    "OpenCode in PATH, no ~/.claude",
    home_dir: tmpdir, opencode: true,
  )
  pass += 1 if assert("no settings.json created", settings.nil?)
  pass += 1 if assert("prints OpenCode instructions", output.any? { |l| l.include?("OpenCode detected") })
  pass += 1 if assert("does not print generic instructions", output.none? { |l| l.include?("Configure it for your agentic tool") })
  fail += (3 - [settings.nil?,
    output.any? { |l| l.include?("OpenCode detected") },
    output.none? { |l| l.include?("Configure it for your agentic tool") }].count(true))
end

# Scenario 7: Both Claude Code and OpenCode
Dir.mktmpdir do |tmpdir|
  harness, output, settings = run_scenario(
    "Both ~/.claude and OpenCode",
    home_dir: tmpdir, opencode: true,
    setup: lambda { |d|
      claude = Pathname.new(d).join(".claude")
      claude.mkpath
      (claude/"settings.json").write("{}\n")
    },
  )
  pass += 1 if assert("hook added to settings", settings&.dig("hooks", "PreToolUse")&.any? { |h| h["hooks"]&.any? { |i| i["command"]&.include?("safe-chains") } })
  pass += 1 if assert("prints 'hook added'", output.any? { |l| l.include?("hook added") })
  pass += 1 if assert("prints OpenCode instructions", output.any? { |l| l.include?("OpenCode detected") })
  pass += 1 if assert("does not print generic instructions", output.none? { |l| l.include?("Configure it for your agentic tool") })
  fail += (4 - [settings&.dig("hooks", "PreToolUse")&.any? { |h| h["hooks"]&.any? { |i| i["command"]&.include?("safe-chains") } },
    output.any? { |l| l.include?("hook added") },
    output.any? { |l| l.include?("OpenCode detected") },
    output.none? { |l| l.include?("Configure it for your agentic tool") }].count(true))
end

# Scenario 8: ~/.claude with existing non-safe-chains hooks
Dir.mktmpdir do |tmpdir|
  harness, output, settings = run_scenario(
    "~/.claude with other PreToolUse hooks",
    home_dir: tmpdir, opencode: false,
    setup: lambda { |d|
      claude = Pathname.new(d).join(".claude")
      claude.mkpath
      existing = {
        "hooks" => {
          "PreToolUse" => [{
            "matcher" => "Bash",
            "hooks" => [{ "type" => "command", "command" => "/usr/local/bin/my-linter" }],
          }],
        },
      }
      (claude/"settings.json").write(JSON.pretty_generate(existing) + "\n")
    },
  )
  hooks = settings&.dig("hooks", "PreToolUse") || []
  pass += 1 if assert("existing hook preserved", hooks.any? { |h| h["hooks"]&.any? { |i| i["command"]&.include?("my-linter") } })
  pass += 1 if assert("safe-chains hook appended", hooks.any? { |h| h["hooks"]&.any? { |i| i["command"]&.include?("safe-chains") } })
  pass += 1 if assert("two hooks total", hooks.length == 2)
  pass += 1 if assert("prints 'hook added'", output.any? { |l| l.include?("hook added") })
  fail += (4 - [hooks.any? { |h| h["hooks"]&.any? { |i| i["command"]&.include?("my-linter") } },
    hooks.any? { |h| h["hooks"]&.any? { |i| i["command"]&.include?("safe-chains") } },
    hooks.length == 2,
    output.any? { |l| l.include?("hook added") }].count(true))
end

puts "\n#{"=" * 40}"
puts "#{pass} passed, #{fail} failed"
exit(fail == 0 ? 0 : 1)
