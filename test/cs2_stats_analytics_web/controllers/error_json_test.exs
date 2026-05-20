defmodule Cs2StatsAnalyticsWeb.ErrorJSONTest do
  use Cs2StatsAnalyticsWeb.ConnCase, async: true

  test "renders 404" do
    assert Cs2StatsAnalyticsWeb.ErrorJSON.render("404.json", %{}) == %{
             errors: %{detail: "Not Found"}
           }
  end

  test "renders 500" do
    assert Cs2StatsAnalyticsWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
