defmodule NbFlop do
  @moduledoc """
  Flop integration for the nb ecosystem.

  NbFlop provides seamless integration between [Flop](https://hexdocs.pm/flop) and the nb
  ecosystem (nb_serializer, nb_inertia, nb_ts). It includes:

  1. **Backend serializers** - Generated into your codebase for serializing `Flop.Meta`
     with full TypeScript type generation via nb_ts
  2. **React components** - Copied into your codebase for pagination, sorting, and filtering
     with Base UI or Radix UI primitives
  3. **Hooks** - UI-agnostic `useFlopParams` hook for state management

  ## Installation

      mix igniter.install nb_flop

  The installer will:
  - Add the `:flop` dependency
  - Generate serializers to `lib/your_app_web/serializers/`
  - Copy React components to `assets/js/components/flop/`
  - Install required npm packages

  ## Usage

  ### Controller

      defmodule MyAppWeb.PostController do
        use MyAppWeb, :controller
        use NbInertia.Controller

        alias MyAppWeb.Serializers.{PostSerializer, FlopMetaSerializer}

        def index(conn, params) do
          case Flop.validate_and_run(Post, params, for: Post) do
            {:ok, {posts, meta}} ->
              render_inertia(conn, :posts_index,
                posts: {PostSerializer, posts},
                meta: {FlopMetaSerializer, meta, schema: Post}
              )

            {:error, changeset} ->
              # Handle validation error
          end
        end
      end

  ### React Component

      import { useFlopParams, Pagination, SortableHeader } from '@/components/flop';
      import { router } from '@/lib/inertia';
      import { posts_path } from '@/routes';

      function PostsIndex({ posts, meta }: PostsIndexProps) {
        const flop = useFlopParams(meta, {
          onParamsChange: (params) => {
            router.visit(posts_path({ query: flopToQueryParams(params) }), {
              preserveState: true,
              preserveScroll: true,
            });
          },
        });

        return (
          <div>
            <table>
              <thead>
                <tr>
                  <SortableHeader
                    field="title"
                    currentSort={flop.params.orderBy?.[0]}
                    currentDirection={flop.params.orderDirections?.[0]}
                    onSort={flop.setSort}
                  >
                    Title
                  </SortableHeader>
                </tr>
              </thead>
              <tbody>
                {posts.map(post => <tr key={post.id}>...</tr>)}
              </tbody>
            </table>

            <Pagination meta={meta} onPageChange={flop.setPage} />
          </div>
        );
      }

  ## Pagination Modes

  NbFlop supports both page-based and cursor-based pagination:

  - **Page-based**: Use `<Pagination>` component with `setPage`, `nextPage`, `previousPage`
  - **Cursor-based**: Use `<CursorPagination>` component with `goToNextCursor`, `goToPreviousCursor`

  ## Schema Introspection

  When you pass `schema: YourSchema` to the `FlopMetaSerializer`, it will automatically
  include `sortableFields` and `filterableFields` metadata in the response, derived from
  your `Flop.Schema` configuration.
  """

  @version "0.1.0"

  @doc """
  Returns the current version of NbFlop.
  """
  def version, do: @version
end
