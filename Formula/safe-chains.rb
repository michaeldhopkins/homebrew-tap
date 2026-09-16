class SafeChains < Formula
  desc "Auto-allow safe, read-only bash commands in agentic coding tools"
  homepage "https://github.com/michaeldhopkins/safe-chains"
  url "https://github.com/michaeldhopkins/safe-chains/archive/refs/tags/v0.230.0.tar.gz"
  sha256 "47315393113f16c80a5eb19c624623ae00e52b91a20818a3bc01be8d5b065171"
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

  # No `post_install`. Homebrew now audits it away in favour of `post_install_steps`, which is a
  # DECLARATIVE file-prep DSL (chmod/chown/mkdir, serialisable to the JSON API) — it cannot express
  # what this block did, which was `ohai` two messages and branch on `which("opencode")`.
  #
  # It did not need to. Every line of it duplicated `caveats` below: run `--setup`, and copy the
  # plugin into `.opencode/plugins/`. `caveats` is where Homebrew puts advice for the person who
  # just installed, it prints on install and on `brew info`, and it does not need a shell-out to
  # decide whether OpenCode is worth mentioning. So the block is gone rather than translated.

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
