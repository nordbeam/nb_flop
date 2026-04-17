defmodule Mix.Tasks.NbFlop.InstallTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.NbFlop.Install

  describe "info/2" do
    test "declares core and optional export dependencies" do
      options = Install.installer_options(["--with-exports"])

      assert Install.optional_dependency_specs(options, []) == [
               {:flop, "~> 0.26"},
               {:csv, "~> 3.2"}
             ]
    end

    test "parses grouped igniter flags for shared nb task namespaces" do
      options = Install.installer_options(["--nb.with-exports"])

      assert Install.optional_dependency_specs(options, []) == [
               {:flop, "~> 0.26"},
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
end
