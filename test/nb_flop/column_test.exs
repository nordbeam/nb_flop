defmodule NbFlop.ColumnTest do
  use ExUnit.Case, async: true

  alias NbFlop.Column

  describe "text/2" do
    test "creates a text column with defaults" do
      column = Column.text(:name)

      assert column.key == :name
      assert column.type == :text
      assert column.label == "Name"
      assert column.sortable == false
      assert column.searchable == false
      assert column.toggleable == true
      assert column.visible == true
      assert column.alignment == :left
    end

    test "accepts options" do
      column = Column.text(:email, sortable: true, searchable: true, label: "Email Address")

      assert column.sortable == true
      assert column.searchable == true
      assert column.label == "Email Address"
    end
  end

  describe "badge/2" do
    test "creates a badge column with colors" do
      column = Column.badge(:status, colors: %{"active" => :success, "inactive" => :danger})

      assert column.type == :badge
      assert column.opts.colors == %{"active" => :success, "inactive" => :danger}
    end
  end

  describe "numeric/2" do
    test "creates a numeric column with right alignment" do
      column = Column.numeric(:price)

      assert column.type == :numeric
      assert column.alignment == :right
    end

    test "accepts formatting options" do
      column = Column.numeric(:price, prefix: "$", decimals: 2)

      assert column.opts.prefix == "$"
      assert column.opts.decimals == 2
    end
  end

  describe "date/2" do
    test "creates a date column with default format" do
      column = Column.date(:created_at)

      assert column.type == :date
      assert column.opts.format == "MMM d, yyyy"
    end

    test "accepts custom format" do
      column = Column.date(:created_at, format: "yyyy-MM-dd")

      assert column.opts.format == "yyyy-MM-dd"
    end
  end

  describe "action/1" do
    test "creates an action column" do
      column = Column.action()

      assert column.key == :_actions
      assert column.type == :action
      assert column.sortable == false
      assert column.toggleable == false
      assert column.alignment == :right
    end
  end
end
