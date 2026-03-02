class SafeChains < Formula
  desc "Auto-allow safe, read-only bash commands in agentic coding tools"
  homepage "https://github.com/michaeldhopkins/safe-chains"
  url "https://github.com/michaeldhopkins/safe-chains/archive/refs/tags/v0.29.1.tar.gz"
  sha256 "05952e37449663f3fe74463303884e48a11159159f867cb21f418c83ef7fee52"
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
      if already_installed
        ohai "safe-chains hook already configured in ~/.claude/settings.json"
        opoo "safe-chains will check every Bash command before Claude Code runs it"
        return
      end

      settings["hooks"] ||= {}
      settings["hooks"]["PreToolUse"] ||= []
      settings["hooks"]["PreToolUse"] << hook_entry
    else
      claude_dir.mkpath
      settings = { "hooks" => { "PreToolUse" => [hook_entry] } }
    end

    settings_path.write(JSON.pretty_generate(settings) + "\n")
    ohai "safe-chains hook added to ~/.claude/settings.json"
    opoo "safe-chains will check every Bash command before Claude Code runs it"
  rescue JSON::ParserError
    opoo "Could not parse ~/.claude/settings.json; skipping hook installation."
    opoo "See: #{homepage}#claude-code-hook"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/safe-chains --version")
  end
end
