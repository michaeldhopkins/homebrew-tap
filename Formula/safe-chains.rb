class SafeChains < Formula
  desc "Auto-allow safe, read-only bash commands in agentic coding tools"
  homepage "https://github.com/michaeldhopkins/safe-chains"
  url "https://github.com/michaeldhopkins/safe-chains/archive/refs/tags/v0.99.0.tar.gz"
  sha256 "92a77388e568795df501601e8985019904c66db41e9bdfa918645f63eb52d513"
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
    ohai "Run 'safe-chains --setup' to configure the Claude Code hook"
    if which("opencode")
      ohai "OpenCode detected — copy the plugin to each project:"
      puts "  cp #{pkgshare}/opencode-plugin.js .opencode/plugins/"
    end
  end

  def caveats
    <<~EOS
      To configure the Claude Code hook:
        safe-chains --setup

      To configure OpenCode, copy the plugin to each project:
        cp #{pkgshare}/opencode-plugin.js .opencode/plugins/

      See #{homepage}#configure for details.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/safe-chains --version")
  end
end
