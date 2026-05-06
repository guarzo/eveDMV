defmodule EveDmv.Auth.EveSsoStrategyExtension do
  @moduledoc """
  Spark DSL extension that swaps the `:eve_sso` OAuth2 strategy's
  `:assent_strategy` to `EveDmv.Auth.EveSsoStrategy` after
  `AshAuthentication`'s own transformer has set the default
  (`Assent.Strategy.OAuth2`).

  This is the integration point that lets us replace the retired
  `https://esi.evetech.net/verify/` `user_url` flow with a JWT-based
  identity check, without forking AshAuthentication.
  """

  use Spark.Dsl.Extension, transformers: [EveDmv.Auth.EveSsoStrategyExtension.Transformer]

  defmodule Transformer do
    @moduledoc false
    use Spark.Dsl.Transformer

    alias Spark.Dsl.Transformer

    @strategy_name :eve_sso
    @custom_strategy EveDmv.Auth.EveSsoStrategy

    @doc false
    @impl Spark.Dsl.Transformer
    def after?(AshAuthentication.Strategy.OAuth2.Transformer), do: true
    def after?(_), do: false

    @doc false
    @impl Spark.Dsl.Transformer
    def before?(_), do: false

    @doc false
    @impl Spark.Dsl.Transformer
    def transform(dsl_state) do
      strategies = Transformer.get_entities(dsl_state, [:authentication, :strategies])

      case Enum.find(strategies, fn strategy ->
             Map.get(strategy, :name) == @strategy_name
           end) do
        nil ->
          {:ok, dsl_state}

        strategy ->
          updated = %{strategy | assent_strategy: @custom_strategy}

          dsl_state =
            Transformer.replace_entity(
              dsl_state,
              [:authentication, :strategies],
              updated,
              &(Map.get(&1, :name) == @strategy_name)
            )

          {:ok, dsl_state}
      end
    end
  end
end
