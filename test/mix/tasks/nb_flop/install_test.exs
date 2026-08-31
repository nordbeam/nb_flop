defmodule Mix.Tasks.NbFlop.InstallTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.NbFlop.Install

  describe "info/2" do
    test "declares core and optional export dependencies" do
      options = Install.installer_options(["--with-exports"])

      assert Install.optional_dependency_specs(options, []) == [
               {:flop, "~> 0.28"},
               {:csv, "~> 3.2"}
             ]
    end

    test "parses grouped igniter flags for shared nb task namespaces" do
      options = Install.installer_options(["--nb.with-exports"])

      assert Install.optional_dependency_specs(options, []) == [
               {:flop, "~> 0.28"},
               {:csv, "~> 3.2"}
             ]
    end

    test "skips dependencies already present in the project" do
      options = Install.installer_options(["--with-exports"])

      assert Install.optional_dependency_specs(options, [:flop, :csv]) == []
      assert Install.optional_dependency_specs(options, [:flop]) == [{:csv, "~> 3.2"}]
    end
  end

  test "hex package includes installer assets" do
    assert "priv" in Mix.Project.config()[:package][:files]
  end

  test "hex package includes usage rules and the prebuilt skill" do
    package_files = Mix.Project.config()[:package][:files]

    assert "usage-rules.md" in package_files
    assert "usage-rules" in package_files
    assert File.exists?("usage-rules/skills/nb-flop/SKILL.md")
    refute File.exists?("skills/nb-flop/SKILL.md")
  end

  describe "Vite+ CLI bootstrap" do
    test "prefers a globally installed vp executable" do
      assert Install.vite_plus_prefix("/usr/local/bin/vp") == "vp"
    end

    test "falls back to Corepack npm 12 when vp is unavailable" do
      assert Install.vite_plus_prefix(nil) ==
               "corepack npm@12.0.2 exec --yes --package=vite-plus@0.3.0 -- vp"
    end

    test "keeps the Corepack/npm 12 fallback pinned and documented" do
      source = File.read!("lib/mix/tasks/nb_flop.install.ex")

      assert source =~ "System.find_executable(\"vp\")"
      assert source =~ "corepack npm@12.0.2 exec --yes --package=vite-plus@0.3.0 -- vp"
      refute source =~ "npm exec --yes --package=vite-plus@0.3.0 -- vp"
    end
  end

  test "recognizes an existing required shadcn component set" do
    files =
      ~w(button badge popover dropdown-menu command input dialog sheet)
      |> Map.new(fn component ->
        {"assets/js/components/ui/#{component}.tsx", "export {}"}
      end)

    assert Install.shadcn_components_exist?(nil, &Map.has_key?(files, &1))
  end
end
