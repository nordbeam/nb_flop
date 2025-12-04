defmodule NbFlop.Table.Builder do
  @moduledoc """
  Builds table resources by executing queries and assembling all data.
  """

  @doc """
  Builds a complete table resource for rendering.

  ## Options

    * `:as` - Override table name for URL namespacing
    * `:endpoint` - Phoenix endpoint for token generation
    * `:query` - Custom base query to use instead of resource()
      (useful for multi-tenant scoping, e.g., `User |> User.for_account(account_id)`)
    * `:preload` - Associations to preload on results
      (e.g., `preload: :organization` or `preload: [:organization, :tags]`)
  """
  def build(table_module, conn, params, opts \\ []) do
    config = table_module.config()
    table_name = Keyword.get(opts, :as, config.name)

    # Parse params with table name prefix
    flop_params = parse_params(params, table_name, config)

    # Execute Flop query - use custom query if provided, otherwise use resource()
    resource = table_module.resource()
    query = Keyword.get(opts, :query, resource)
    repo = table_module.repo()

    case Flop.validate_and_run(query, flop_params, repo: repo, for: resource) do
      {:ok, {rows, meta}} ->
        # Collect preloads from columns and merge with explicit preloads
        columns = table_module.columns()
        column_preloads = NbFlop.Column.collect_preloads(columns)
        opts_with_preloads = merge_preloads(opts, column_preloads)

        # Apply all preloads (explicit + column-defined)
        rows = apply_preloads(rows, repo, opts_with_preloads)
        build_resource(table_module, conn, rows, meta, params, opts)

      {:error, changeset} ->
        # Return empty resource with error
        %{
          data: [],
          meta: build_empty_meta(config),
          state: build_state(flop_params, config),
          columns: serialize_columns(table_module.columns()),
          filters: serialize_filters(table_module.filters()),
          actions: serialize_actions(table_module.actions()),
          bulk_actions: serialize_bulk_actions(table_module.bulk_actions()),
          exports: serialize_exports(table_module.exports()),
          empty_state: serialize_empty_state(table_module.empty_state()),
          name: table_name,
          token: nil,
          per_page_options: config.per_page_options,
          sticky_header: config.sticky_header,
          searchable: config.searchable,
          search_placeholder: config.search_placeholder,
          error: format_changeset_errors(changeset)
        }
    end
  end

  defp build_resource(table_module, conn, rows, meta, _params, opts) do
    config = table_module.config()
    table_name = Keyword.get(opts, :as, config.name)
    columns = table_module.columns()
    actions = table_module.actions()
    bulk_actions = table_module.bulk_actions()

    # Transform rows
    transformed_rows =
      rows
      |> Enum.map(fn row ->
        data =
          row
          |> transform_row_values(columns)
          |> Map.put(:id, row.id)
          |> add_action_states(actions, row, conn)
          |> add_selectability(table_module, row, conn, bulk_actions)

        # Call transform_row with correct argument order: (row, data, conn)
        table_module.transform_row(row, data, conn)
      end)

    # Generate token for action authentication
    token = generate_token(table_module, conn, opts)

    %{
      data: transformed_rows,
      meta: serialize_meta(meta),
      state: build_state_from_meta(meta, config),
      columns: serialize_columns(columns),
      filters: serialize_filters(table_module.filters()),
      actions: serialize_actions(actions),
      bulk_actions: serialize_bulk_actions(bulk_actions),
      exports: serialize_exports(table_module.exports()),
      empty_state: serialize_empty_state(table_module.empty_state()),
      views: load_views(table_module, conn),
      name: table_name,
      token: token,
      per_page_options: config.per_page_options,
      sticky_header: config.sticky_header,
      searchable: config.searchable,
      search_placeholder: config.search_placeholder
    }
  end

  # Parse URL params respecting table name prefix
  defp parse_params(params, table_name, config) do
    # Check for prefixed params first (e.g., "users[page]")
    prefixed_params = Map.get(params, table_name, %{})

    base_params =
      if map_size(prefixed_params) > 0 do
        prefixed_params
      else
        params
      end

    # Build Flop params
    flop_params = %{}

    # Page/pagination
    flop_params =
      case Map.get(base_params, "page") do
        nil -> flop_params
        page -> Map.put(flop_params, :page, parse_int(page))
      end

    flop_params =
      case Map.get(base_params, "page_size") || Map.get(base_params, "per_page") do
        nil -> Map.put(flop_params, :page_size, config.default_per_page)
        size -> Map.put(flop_params, :page_size, parse_int(size))
      end

    # Sorting
    flop_params =
      case Map.get(base_params, "order_by") || Map.get(base_params, "sort") do
        nil ->
          case config.default_sort do
            {field, direction} ->
              flop_params
              |> Map.put(:order_by, [field])
              |> Map.put(:order_directions, [direction])

            nil ->
              flop_params
          end

        sort when is_binary(sort) ->
          # Check for separate order_direction param first
          direction =
            case Map.get(base_params, "order_direction") do
              "desc" -> :desc
              "asc" -> :asc
              nil -> parse_sort_direction(sort)
            end

          field = parse_sort_field(sort)

          flop_params
          |> Map.put(:order_by, [field])
          |> Map.put(:order_directions, [direction])
      end

    # Filters
    flop_params =
      case Map.get(base_params, "filters") do
        nil ->
          flop_params

        filters when is_list(filters) ->
          parsed_filters =
            Enum.map(filters, fn filter ->
              %{
                field: String.to_existing_atom(filter["field"]),
                op: parse_operator(filter["op"]),
                value: filter["value"]
              }
            end)

          Map.put(flop_params, :filters, parsed_filters)

        filters when is_map(filters) ->
          # Check if this is indexed filters (from query string like filters[0][field]=...)
          # or simple shorthand filters (like filters[field]=value)
          parsed_filters =
            if indexed_filters?(filters) do
              # Indexed filters - convert to list and parse like list case
              filters
              |> Map.values()
              |> Enum.map(fn filter ->
                %{
                  field: String.to_existing_atom(filter["field"]),
                  op: parse_operator(filter["op"]),
                  value: filter["value"]
                }
              end)
            else
              # Simple shorthand filters
              Enum.map(filters, fn {field, value} ->
                %{field: String.to_existing_atom(field), op: :==, value: value}
              end)
            end

          Map.put(flop_params, :filters, parsed_filters)
      end

    flop_params
  end

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)

  # Check if filters map is indexed (keys like "0", "1", etc. with map values)
  # vs simple shorthand (keys are field names, values are filter values)
  defp indexed_filters?(filters) when is_map(filters) do
    case Map.keys(filters) do
      [] ->
        false

      keys ->
        # Check if first key looks like an index and value is a map with "field" key
        first_key = hd(keys)
        first_value = Map.get(filters, first_key)

        is_binary(first_key) and
          String.match?(first_key, ~r/^\d+$/) and
          is_map(first_value) and
          Map.has_key?(first_value, "field")
    end
  end

  # Extract just the field name from sort string
  defp parse_sort_field(sort) do
    case String.split(sort, ":") do
      ["-" <> field] -> String.to_existing_atom(field)
      [field, _dir] -> String.to_existing_atom(field)
      [field] -> String.to_existing_atom(field)
    end
  end

  # Extract direction from sort string (when no separate order_direction param)
  defp parse_sort_direction(sort) do
    case String.split(sort, ":") do
      [_field, "desc"] -> :desc
      [_field, "asc"] -> :asc
      ["-" <> _field] -> :desc
      [_field] -> :asc
    end
  end

  defp parse_operator(nil), do: :==
  defp parse_operator("=="), do: :==
  defp parse_operator("!="), do: :!=
  defp parse_operator("ilike"), do: :ilike
  defp parse_operator("contains"), do: :ilike
  defp parse_operator(">"), do: :>
  defp parse_operator(">="), do: :>=
  defp parse_operator("<"), do: :<
  defp parse_operator("<="), do: :<=
  defp parse_operator("in"), do: :in
  defp parse_operator("not_in"), do: :not_in
  defp parse_operator(op) when is_atom(op), do: op
  defp parse_operator(op), do: String.to_existing_atom(op)

  # Transform row values through column compute and map_as functions
  defp transform_row_values(row, columns) do
    row_map = if is_struct(row), do: Map.from_struct(row), else: row

    Enum.reduce(columns, %{}, fn column, acc ->
      case column.key do
        :_actions ->
          acc

        key ->
          # Get base value - either computed from row or from row field
          value =
            if column.compute do
              column.compute.(row)
            else
              Map.get(row_map, key)
            end

          # Apply map_as transformation if present
          transformed =
            if column.map_as do
              column.map_as.(value)
            else
              value
            end

          # Use camelized key for output (matches column serialization)
          output_key = camelize(to_string(key))
          Map.put(acc, output_key, transformed)
      end
    end)
  end

  # Add action states to row
  defp add_action_states(data, actions, row, conn) do
    action_states =
      actions
      |> Enum.map(fn action ->
        {to_string(action.name), NbFlop.Action.evaluate_for_row(action, row, conn)}
      end)
      |> Map.new()

    Map.put(data, :_actions, action_states)
  end

  # Add selectability for bulk actions
  defp add_selectability(data, _table_module, _row, _conn, []), do: data

  defp add_selectability(data, table_module, row, conn, _bulk_actions) do
    selectable = table_module.selectable?(row, conn)
    Map.put(data, :_selectable, selectable)
  end

  # Generate signed token for action authentication
  defp generate_token(table_module, conn, opts) do
    endpoint = Keyword.get(opts, :endpoint) || get_endpoint(conn)

    if endpoint do
      NbFlop.Token.sign(endpoint, table_module)
    else
      nil
    end
  end

  defp get_endpoint(%Plug.Conn{} = conn) do
    conn.private[:phoenix_endpoint]
  end

  defp get_endpoint(_), do: nil

  # Serialize Flop.Meta
  defp serialize_meta(%Flop.Meta{} = meta) do
    %{
      current_page: meta.current_page,
      total_pages: meta.total_pages,
      total_count: meta.total_count,
      page_size: meta.page_size,
      has_next_page: meta.has_next_page?,
      has_previous_page: meta.has_previous_page?,
      next_page: if(meta.has_next_page?, do: (meta.current_page || 1) + 1),
      previous_page: if(meta.has_previous_page?, do: (meta.current_page || 1) - 1),
      start_cursor: meta.start_cursor,
      end_cursor: meta.end_cursor,
      flop: serialize_flop(meta.flop)
    }
  end

  defp serialize_flop(%Flop{} = flop) do
    %{
      order_by: flop.order_by,
      order_directions: flop.order_directions,
      page: flop.page,
      page_size: flop.page_size,
      filters:
        Enum.map(flop.filters || [], fn f ->
          %{field: f.field, op: to_string(f.op), value: f.value}
        end)
    }
  end

  defp serialize_flop(_), do: nil

  defp build_empty_meta(config) do
    %{
      current_page: 1,
      total_pages: 0,
      total_count: 0,
      page_size: config.default_per_page,
      has_next_page: false,
      has_previous_page: false,
      next_page: nil,
      previous_page: nil,
      start_cursor: nil,
      end_cursor: nil,
      flop: nil
    }
  end

  defp build_state(flop_params, config) do
    %{
      sort:
        case {flop_params[:order_by], flop_params[:order_directions]} do
          {[field], [dir]} -> %{field: to_string(field), direction: to_string(dir)}
          _ -> nil
        end,
      filters:
        Enum.map(flop_params[:filters] || [], fn f ->
          %{field: to_string(f.field), op: to_string(f.op), value: f.value}
        end),
      page: flop_params[:page] || 1,
      per_page: flop_params[:page_size] || config.default_per_page,
      search: nil,
      columns: []
    }
  end

  defp build_state_from_meta(%Flop.Meta{flop: flop}, config) do
    %{
      sort:
        case {flop.order_by, flop.order_directions} do
          {[field], [dir]} -> %{field: to_string(field), direction: to_string(dir)}
          _ -> nil
        end,
      filters:
        Enum.map(flop.filters || [], fn f ->
          %{field: to_string(f.field), op: to_string(f.op), value: f.value}
        end),
      page: flop.page || 1,
      per_page: flop.page_size || config.default_per_page,
      search: nil,
      columns: []
    }
  end

  # Serialize columns
  defp serialize_columns(columns) do
    Enum.map(columns, &serialize_column/1)
  end

  defp serialize_column(%NbFlop.Column{} = col) do
    base = %{
      key: camelize(to_string(col.key)),
      type: to_string(col.type),
      label: col.label,
      sortable: col.sortable,
      searchable: col.searchable,
      toggleable: col.toggleable,
      visible: col.visible,
      stickable: col.stickable,
      alignment: to_string(col.alignment),
      wrap: col.wrap,
      truncate: col.truncate
    }

    # Add optional fields
    base = if col.header_class, do: Map.put(base, :header_class, col.header_class), else: base
    base = if col.cell_class, do: Map.put(base, :cell_class, col.cell_class), else: base

    # Add type-specific options
    Map.merge(base, serialize_column_opts(col.type, col.opts))
  end

  defp serialize_column_opts(:badge, opts), do: %{colors: opts.colors}

  defp serialize_column_opts(:numeric, opts),
    do: Map.take(opts, [:prefix, :suffix, :decimals, :thousands_separator])

  defp serialize_column_opts(:date, opts), do: %{format: opts.format}
  defp serialize_column_opts(:datetime, opts), do: %{format: opts.format}

  defp serialize_column_opts(:image, opts),
    do: Map.take(opts, [:width, :height, :rounded, :fallback])

  defp serialize_column_opts(_, _), do: %{}

  # Serialize filters
  defp serialize_filters(filters) do
    Enum.map(filters, &serialize_filter/1)
  end

  defp serialize_filter(%NbFlop.Filter{} = filter) do
    base = %{
      field: to_string(filter.field),
      type: to_string(filter.type),
      label: filter.label,
      clauses: Enum.map(filter.clauses, &to_string/1),
      default_clause: to_string(filter.default_clause),
      nullable: filter.nullable
    }

    # Add options for set filters
    base =
      if filter.options,
        do: Map.put(base, :options, serialize_filter_options(filter.options)),
        else: base

    # Add min/max for numeric/date filters
    base = if filter.min, do: Map.put(base, :min, filter.min), else: base
    if filter.max, do: Map.put(base, :max, filter.max), else: base
  end

  defp serialize_filter_options(options) do
    Enum.map(options, fn
      {value, label} -> %{value: value, label: label}
      %{value: _, label: _} = opt -> opt
    end)
  end

  # Serialize actions
  defp serialize_actions(actions) do
    Enum.map(actions, &serialize_action/1)
  end

  defp serialize_action(%NbFlop.Action{} = action) do
    base = %{
      name: to_string(action.name),
      label: action.label,
      variant: to_string(action.variant),
      frontend: action.frontend
    }

    base = if action.icon, do: Map.put(base, :icon, action.icon), else: base

    if action.confirmation do
      Map.put(base, :confirmation, serialize_confirmation(action.confirmation))
    else
      base
    end
  end

  defp serialize_confirmation(%NbFlop.Confirmation{} = conf) do
    %{
      title: conf.title,
      message: conf.message,
      confirm_button: conf.confirm_button,
      cancel_button: conf.cancel_button,
      variant: to_string(conf.variant)
    }
    |> maybe_add(:icon, conf.icon)
  end

  # Serialize bulk actions
  defp serialize_bulk_actions(bulk_actions) do
    Enum.map(bulk_actions, &serialize_bulk_action/1)
  end

  defp serialize_bulk_action(%NbFlop.BulkAction{} = action) do
    base = %{
      name: to_string(action.name),
      label: action.label,
      variant: to_string(action.variant),
      frontend: action.frontend
    }

    base = if action.icon, do: Map.put(base, :icon, action.icon), else: base

    if action.confirmation do
      Map.put(base, :confirmation, serialize_confirmation(action.confirmation))
    else
      base
    end
  end

  # Serialize exports
  defp serialize_exports(nil), do: []

  defp serialize_exports(exports) do
    Enum.map(exports, fn export ->
      %{
        name: to_string(export.name),
        label: export.label,
        format: to_string(export.format)
      }
    end)
  end

  # Serialize empty state
  defp serialize_empty_state(nil), do: nil

  defp serialize_empty_state(%NbFlop.EmptyState{} = state) do
    base = %{
      title: state.title
    }

    base = if state.message, do: Map.put(base, :message, state.message), else: base
    base = if state.icon, do: Map.put(base, :icon, state.icon), else: base
    if state.action, do: Map.put(base, :action, state.action), else: base
  end

  # Load saved views (placeholder - actual implementation in views module)
  defp load_views(table_module, _conn) do
    views_config = table_module.views_config()

    if views_config && views_config.enabled do
      %{
        enabled: true,
        list: [],
        current: nil
      }
    else
      %{enabled: false, list: [], current: nil}
    end
  end

  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  # Handle Flop.Meta with errors (from validation failures)
  defp format_changeset_errors(%Flop.Meta{errors: errors}) when is_list(errors) do
    Enum.map(errors, fn {field, messages} ->
      formatted_messages =
        Enum.map(messages, fn
          {msg, _opts} -> msg
          msg when is_binary(msg) -> msg
        end)

      {field, formatted_messages}
    end)
    |> Map.new()
  end

  defp format_changeset_errors(_), do: %{}

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)

  # Merge explicit preloads from opts with preloads collected from columns
  defp merge_preloads(opts, column_preloads) when column_preloads == [] do
    opts
  end

  defp merge_preloads(opts, column_preloads) do
    explicit_preloads = Keyword.get(opts, :preload)

    merged =
      case explicit_preloads do
        nil -> column_preloads
        preload when is_atom(preload) -> Enum.uniq([preload | column_preloads])
        preloads when is_list(preloads) -> Enum.uniq(preloads ++ column_preloads)
      end

    Keyword.put(opts, :preload, merged)
  end

  # Apply preloads if specified in options
  defp apply_preloads(rows, repo, opts) do
    case Keyword.get(opts, :preload) do
      nil -> rows
      preloads -> repo.preload(rows, preloads)
    end
  end

  # Convert snake_case to camelCase (to match nb_inertia prop camelization)
  # Only camelizes if nb_inertia is configured to camelize props, or if no nb_inertia
  defp camelize(string) when is_binary(string) do
    if should_camelize?() do
      do_camelize(string)
    else
      string
    end
  end

  defp do_camelize(string) do
    string
    |> String.split("_")
    |> case do
      [first | rest] ->
        first <> Enum.map_join(rest, "", &String.capitalize/1)

      [] ->
        ""
    end
  end

  # Check if keys should be camelized
  # 1. Check NbFlop config first (allows explicit override)
  # 2. Fall back to nb_inertia config if available
  # 3. Default to true (for Inertia.js convention compatibility)
  defp should_camelize? do
    case Application.get_env(:nb_flop, :camelize_keys) do
      nil ->
        # Check nb_inertia config if available
        if Code.ensure_loaded?(NbInertia.Config) do
          NbInertia.Config.camelize_props()
        else
          # Default to true for Inertia.js compatibility
          true
        end

      value when is_boolean(value) ->
        value
    end
  end
end
