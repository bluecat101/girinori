package com.example.girinori

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import org.json.JSONArray

class RouteWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(
                context,
                appWidgetManager,
                appWidgetId
            )
        }
    }

    companion object {

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            // -----------------------------------------
            // Widgetのベースレイアウト
            // -----------------------------------------

            val views = RemoteViews(
                context.packageName,
                R.layout.route_widget
            )

            // -----------------------------------------
            // Flutterから保存されたデータを取得
            // -----------------------------------------

            val prefs = context.getSharedPreferences(
                "route_widget",
                Context.MODE_PRIVATE
            )

            val route = prefs.getString(
                "route",
                "ルート未設定"
            ) ?: "ルート未設定"

            val stationsJson = prefs.getString(
                "stations",
                "[]"
            ) ?: "[]"

            // -----------------------------------------
            // ルート名
            // -----------------------------------------
            views.setTextViewText(
                R.id.widget_route,
                route
            )

            // -----------------------------------------
            // 駅一覧コンテナを取得
            // -----------------------------------------
            val stations = views.apply {
                // 何もしない
            }

            // -----------------------------------------
            // 駅情報をJSONから取得
            // -----------------------------------------
            val stationArray = try {
                JSONArray(stationsJson)
            } catch (e: Exception) {
                JSONArray()
            }

            // -----------------------------------------
            // 駅一覧を動的に追加
            // -----------------------------------------
            for (i in 0 until stationArray.length()) {
                val station = stationArray.getJSONObject(i)
                val stationName = station.optString(
                    "station",
                    ""
                )
                val arrival = station.optString(
                    "arrival",
                    ""
                )
                val departure = station.optString(
                    "departure",
                    ""
                )
                // 駅1個分のレイアウト
                val row = RemoteViews(
                    context.packageName,
                    R.layout.widget_station_row
                )

                // -----------------------------------------
                // 駅名
                // -----------------------------------------
                row.setTextViewText(
                    R.id.station_name,
                    "● $stationName"
                )

                // -----------------------------------------
                // 到着時刻
                // -----------------------------------------
                if (arrival.isNotEmpty()) {
                    row.setTextViewText(
                        R.id.station_arrival,
                        "$arrival 着"
                    )
                } else {
                    row.setTextViewText(
                        R.id.station_arrival,
                        ""
                    )
                }

                // -----------------------------------------
                // 出発時刻
                // -----------------------------------------
                if (departure.isNotEmpty()) {
                    row.setTextViewText(
                        R.id.station_departure,
                        "$departure 発"
                    )
                } else {
                    row.setTextViewText(
                        R.id.station_departure,
                        ""
                    )
                }

                // -----------------------------------------
                // 縦線
                //
                // 最初と最後の駅には線を表示しない
                // -----------------------------------------
                if (i == 0 || i == stationArray.length() - 1) {
                    row.setTextViewText(
                        R.id.station_line,
                        ""
                    )
                } else {
                    row.setTextViewText(
                        R.id.station_line,
                        "│"
                    )
                }

                // -----------------------------------------
                // 駅行をWidgetに追加
                // -----------------------------------------
                views.addView(
                    R.id.widget_station_container,
                    row
                )
            }

            // -----------------------------------------
            // Widgetを更新
            // -----------------------------------------
            appWidgetManager.updateAppWidget(
                appWidgetId,
                views
            )
        }
    }
}