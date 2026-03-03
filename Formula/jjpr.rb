class Jjpr < Formula
  desc "Multi-forge stacked pull requests for Jujutsu"
  homepage "https://github.com/michaeldhopkins/jjpr"
  url "https://github.com/michaeldhopkins/jjpr/archive/refs/tags/v0.11.5.tar.gz"
  sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/michaeldhopkins/jjpr.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args

    ENV["JJPR_ASSETS_DIR"] = (buildpath/"dist-assets").to_s
    system "cargo", "run", "--locked", "--example", "generate_assets"
    man1.install buildpath/"dist-assets/jjpr.1"
    bash_completion.install buildpath/"dist-assets/completions/jjpr.bash" => "jjpr"
    zsh_completion.install buildpath/"dist-assets/completions/_jjpr"
    fish_completion.install buildpath/"dist-assets/completions/jjpr.fish"
  end

  def caveats
    <<~EOS
      jjpr requires Jujutsu (jj) 0.36+ and a colocated jj/git repository.

      Install jj if you haven't already:
        brew install jj

      Authentication is token-based. If you use the GitHub or GitLab CLI,
      jjpr picks up your existing credentials automatically:
        gh auth login      # GitHub
        glab auth login    # GitLab

      Otherwise, set a token environment variable:
        export GITHUB_TOKEN=...   # GitHub
        export GITLAB_TOKEN=...   # GitLab
        export FORGEJO_TOKEN=...  # Forgejo/Codeberg

      Verify your setup:
        jjpr auth test
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/jjpr --version")
  end
end
