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

  defp get(path, query_params \\ []) do
    with {:ok, api_key} <- api_key() do
      url = build_url(path, query_params)

      request =
        Finch.build(:get, url, [
          {"accept", "application/json"},
          {"authorization", "Bearer #{api_key}"}
        ])

      case Finch.request(request, Cs2StatsAnalytics.Finch) do
        {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
          decode_json(body)

        {:ok, %Finch.Response{status: 401}} ->
          {:error, :unauthorized}

        {:ok, %Finch.Response{status: 403}} ->
          {:error, :forbidden}

        {:ok, %Finch.Response{status: 404}} ->
          {:error, :not_found}

        {:ok, %Finch.Response{status: 429}} ->
          {:error, :rate_limited}

        {:ok, %Finch.Response{status: status, body: body}} ->
          {:error, {:faceit_error, status, body}}

        {:error, reason} ->
          {:error, {:request_failed, reason}}
      end
    end
  end

  defp build_url(path, []), do: @base_url <> path

  defp build_url(path, query_params) do
    @base_url <> path <> "?" <> URI.encode_query(query_params)
  end

  defp decode_json(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _reason} -> {:error, :invalid_json}
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
