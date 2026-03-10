class Branchdiff < Formula
  desc "Terminal UI showing unified diff of current branch vs its base"
  homepage "https://github.com/michaeldhopkins/branchdiff"
  url "https://github.com/michaeldhopkins/branchdiff/archive/refs/tags/v0.57.0.tar.gz"
  sha256 "5825016fd5ceb5b32e598400ce0d057b41109c037706121b4b164e5f6b2986d6"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/michaeldhopkins/branchdiff.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args

    ENV["BRANCHDIFF_ASSETS_DIR"] = (buildpath/"dist-assets").to_s
    system "cargo", "run", "--locked", "--example", "generate_assets"
    man1.install buildpath/"dist-assets/branchdiff.1"
    bash_completion.install buildpath/"dist-assets/completions/branchdiff.bash" => "branchdiff"
    zsh_completion.install buildpath/"dist-assets/completions/_branchdiff"
    fish_completion.install buildpath/"dist-assets/completions/branchdiff.fish"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/branchdiff --version")
  end
end
