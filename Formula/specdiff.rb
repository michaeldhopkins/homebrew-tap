class Specdiff < Formula
  desc "Show test outline changes on a branch"
  homepage "https://github.com/michaeldhopkins/specdiff"
  url "https://github.com/michaeldhopkins/specdiff/archive/refs/tags/v0.21.0.tar.gz"
  sha256 "c219c8a8f4afe187707942335b1ccd4c9ecdf8df3f16785b230d03c73ec973f7"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/michaeldhopkins/specdiff.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args

    ENV["SPECDIFF_ASSETS_DIR"] = (buildpath/"dist-assets").to_s
    system "cargo", "run", "--locked", "--example", "generate_assets"
    man1.install buildpath/"dist-assets/specdiff.1"
    bash_completion.install buildpath/"dist-assets/completions/specdiff.bash" => "specdiff"
    zsh_completion.install buildpath/"dist-assets/completions/_specdiff"
    fish_completion.install buildpath/"dist-assets/completions/specdiff.fish"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/specdiff --version")
  end
end
