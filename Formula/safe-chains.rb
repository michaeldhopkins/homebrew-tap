class SafeChains < Formula
  desc "Auto-allow safe, read-only bash commands in agentic coding tools"
  homepage "https://github.com/michaeldhopkins/safe-chains"
  url "https://github.com/michaeldhopkins/safe-chains/archive/refs/tags/v0.28.1.tar.gz"
  sha256 "PLACEHOLDER"
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
  end

  def post_install
    require "json"

    claude_dir = Pathname.new(Dir.home)/".claude"
    settings_path = claude_dir/"settings.json"
    binary_path = "#{opt_bin}/safe-chains"

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
      already_installed = pre_tool_use.any? do |h|
        h["hooks"]&.any? { |inner| inner["command"]&.include?("safe-chains") }
      end
      return if already_installed

      settings["hooks"] ||= {}
      settings["hooks"]["PreToolUse"] ||= []
      settings["hooks"]["PreToolUse"] << hook_entry
    else
      claude_dir.mkpath
      settings = { "hooks" => { "PreToolUse" => [hook_entry] } }
    end

    settings_path.write(JSON.pretty_generate(settings) + "\n")
  rescue JSON::ParserError
    opoo "Could not parse ~/.claude/settings.json; skipping hook installation."
    opoo "See: #{homepage}#claude-code-hook"
  end

  def caveats
    <<~EOS
      A PreToolUse hook has been added to ~/.claude/settings.json
      so Claude Code will automatically use safe-chains.

      To verify:
        cat ~/.claude/settings.json

      The hook references: #{opt_bin}/safe-chains
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/safe-chains --version")
  end
end
