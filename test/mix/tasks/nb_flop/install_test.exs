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

  describe "Vite+ CLI bootstrap" do
    test "prefers a globally installed vp executable" do
      assert Install.vite_plus_prefix("/usr/local/bin/vp") == "vp"
    end

    test "falls back to npm exec when vp is unavailable" do
      assert Install.vite_plus_prefix(nil) ==
               "npm exec --yes --package=vite-plus@0.3.0 -- vp"
    end

    test "keeps the fallback pinned and documented in the installer" do
      source = File.read!("lib/mix/tasks/nb_flop.install.ex")

      assert source =~ "System.find_executable(\"vp\")"
      assert source =~ "npm exec --yes --package=vite-plus@0.3.0 -- vp"
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
