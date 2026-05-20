defmodule Cs2StatsAnalyticsWeb.PageController do
  use Cs2StatsAnalyticsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
