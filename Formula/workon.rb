class Workon < Formula
  desc "Development workspace launcher with Zellij, Claude CLI, and branchdiff"
  homepage "https://github.com/michaeldhopkins/workon"
  url "https://github.com/michaeldhopkins/workon/archive/refs/tags/v0.15.0.tar.gz"
  sha256 "e21ad6bf71631d87b8afcd93e8ac1b19eb0d827ca2314cc4dc421980f7caa320"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/michaeldhopkins/workon.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args

    ENV["WORKON_ASSETS_DIR"] = (buildpath/"dist-assets").to_s
    system "cargo", "run", "--locked", "--example", "generate_assets"
    man1.install buildpath/"dist-assets/workon.1"
    bash_completion.install buildpath/"dist-assets/completions/workon.bash" => "workon"
    zsh_completion.install buildpath/"dist-assets/completions/_workon"
    fish_completion.install buildpath/"dist-assets/completions/workon.fish"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/workon --version")
  end
end
