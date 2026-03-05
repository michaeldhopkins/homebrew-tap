class SafeChains < Formula
  desc "Auto-allow safe, read-only bash commands in agentic coding tools"
  homepage "https://github.com/michaeldhopkins/safe-chains"
  url "https://github.com/michaeldhopkins/safe-chains/archive/refs/tags/v0.50.0.tar.gz"
  sha256 "4e16f70e6c2ef2c2ebeb5de29e5fd7cd6de2b0648e963b5a437245a06acb375e"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/michaeldhopkins/safe-chains.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args

    ENV["SAFE_CHAINS_ASSETS_DIR"] = (buildpath/"dist-assets").to_s
    system "cargo", "run", "--locked", "--example", "generate_assets"
    man1.install buildpath/"dist-assets/safe-chains.1"
    bash_completion.install buildpath/"dist-assets/completions/safe-chains.bash" => "safe-chains"
    zsh_completion.install buildpath/"dist-assets/completions/_safe-chains"
    fish_completion.install buildpath/"dist-assets/completions/safe-chains.fish"
    pkgshare.install "opencode-plugin.js"
  end

  def post_install
    require "json"

    configured = []
    binary_path = "#{opt_bin}/safe-chains"

    claude_dir = Pathname.new(Dir.home)/".claude"
    configure_claude_code(claude_dir, binary_path, configured) if claude_dir.exist?

    opencode_available = which("opencode")

    configured.each { |msg| ohai msg }

    if opencode_available
      ohai "OpenCode detected — copy the plugin to each project:"
      puts "  cp #{pkgshare}/opencode-plugin.js .opencode/plugins/"
    end

    if configured.empty? && !opencode_available
      ohai "safe-chains installed. Configure it for your agentic tool:"
      puts "  Claude Code: #{homepage}#claude-code"
      puts "  OpenCode:    cp #{pkgshare}/opencode-plugin.js .opencode/plugins/"
    end

    opoo "safe-chains will check every Bash command before your agentic tool runs it"
  end

  def configure_claude_code(claude_dir, binary_path, configured)
    settings_path = claude_dir/"settings.json"

    hook_entry = {
      "matcher" => "Bash",
      "hooks"   => [{
        "type"    => "command",
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
    opoo "See: #{homepage}#claude-code"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/safe-chains --version")
  end
end
