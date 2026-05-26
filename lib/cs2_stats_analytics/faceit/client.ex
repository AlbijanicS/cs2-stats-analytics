defmodule Cs2StatsAnalytics.Faceit.Client do
  @base_url "https://open.faceit.com/data/v4"
  @game "cs2"

  def get_player_by_nickname(nickname) do
    case get("/players", nickname: nickname, game: @game) do
      {:ok, body} -> {:ok, body}
      {:error, :not_found} -> {:error, :player_not_found}
      error -> error
    end
  end

  def get_player_history(player_id, limit \\ 30) do
    case get("/players/#{player_id}/history", game: @game, limit: limit) do
      {:ok, body} -> {:ok, body}
      {:error, :not_found} -> {:error, :player_history_not_found}
      error -> error
    end
  end

  def get_match_stats(match_id) do
    case get("/matches/#{match_id}/stats") do
      {:ok, body} -> {:ok, body}
      {:error, :not_found} -> {:error, :match_stats_not_found}
      error -> error
    end
  end

  def get_player_ranking(player_id, region, country \\ nil) do
    query_params =
      [country: country]
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)

    case get("/rankings/games/#{@game}/regions/#{region}/players/#{player_id}", query_params) do
      {:ok, body} -> {:ok, body}
      {:error, :not_found} -> {:error, :player_ranking_not_found}
      error -> error
    end
  end

  defp get(path, query_params \\ []) do
    with {:ok, api_key} <- api_key() do
      case Req.get(
             url: @base_url <> path,
             params: query_params,
             headers: [
               {"accept", "application/json"},
               {"authorization", "Bearer #{api_key}"}
             ],
             retry: false
           ) do
        {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
          {:ok, body}

        {:ok, %Req.Response{status: 401}} ->
          {:error, :unauthorized}

        {:ok, %Req.Response{status: 403}} ->
          {:error, :forbidden}

        {:ok, %Req.Response{status: 404}} ->
          {:error, :not_found}

        {:ok, %Req.Response{status: 429}} ->
          {:error, :rate_limited}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, {:faceit_error, status, body}}

        {:error, %Jason.DecodeError{}} ->
          {:error, :invalid_json}

        {:error, reason} ->
          {:error, {:request_failed, reason}}
      end
    end
  end

  defp api_key do
    case System.get_env("FACEIT_API_KEY") do
      nil -> {:error, :missing_faceit_api_key}
      "" -> {:error, :missing_faceit_api_key}
      api_key -> {:ok, api_key}
    end
  end
end
