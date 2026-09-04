package com.example.girinori

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
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
            // 駅情報をクリア
            // -----------------------------------------
            views.removeAllViews(
                R.id.widget_station_container
            )

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

            val stationText = when {
                i == 0 -> {
                    "● $stationName"
                }

                i == stationArray.length() - 1 -> {
                    "● $stationName"
                }

                else -> {
                    "├─ $stationName"
                }
            }

            row.setTextViewText(
                R.id.station_name,
                stationText
            )
            // -----------------------------------------
            // 駅名・時刻の色
            // -----------------------------------------

            when {
                i == 0 -> {
                    // 出発駅
                    row.setTextColor(
                        R.id.station_name,
                        android.graphics.Color.rgb(80, 170, 255)
                    )

                    row.setTextColor(
                        R.id.station_time,
                        android.graphics.Color.rgb(80, 170, 255)
                    )
                }

                i == stationArray.length() - 1 -> {
                    // 到着駅
                    row.setTextColor(
                        R.id.station_name,
                        android.graphics.Color.rgb(0, 230, 118)
                    )

                    row.setTextColor(
                        R.id.station_time,
                        android.graphics.Color.rgb(0, 230, 118)
                    )
                }

                else -> {
                    // 経由駅
                    row.setTextColor(
                        R.id.station_name,
                        android.graphics.Color.WHITE
                    )

                    row.setTextColor(
                        R.id.station_time,
                        android.graphics.Color.LTGRAY
                    )
                }
            }

            // -----------------------------------------
            // 時刻
            // -----------------------------------------

            val timeText = when {
                arrival.isNotEmpty() && departure.isNotEmpty() -> {
                    "$arrival 着 → $departure 発"
                }

                arrival.isNotEmpty() -> {
                    "$arrival 着"
                }

                departure.isNotEmpty() -> {
                    "$departure 発"
                }

                else -> {
                    ""
                }
            }

            row.setTextViewText(
                R.id.station_time,
                timeText
            )

            // -----------------------------------------
            // 駅行をWidgetに追加
            // -----------------------------------------

            views.addView(
                R.id.widget_station_container,
                row
            )

            }
            // -----------------------------------------
            // Widgetをタップしたときにアプリを起動するIntentを設定
            // -----------------------------------------
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                pendingIntent
            )
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