class Workon < Formula
  desc "Development workspace launcher with Zellij, Claude CLI, and branchdiff"
  homepage "https://github.com/michaeldhopkins/workon"
  url "https://github.com/michaeldhopkins/workon/archive/refs/tags/v0.16.1.tar.gz"
  sha256 "4cb5ee8a4afdabfb029d1f4407e11dc57c68ee3f18913d18d2bf097d6a25abc8"
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
