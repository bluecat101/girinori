import 'package:flutter/material.dart';
import 'package:girinori/controllers/line_controller.dart';
import 'package:girinori/controllers/timetable_controller.dart';
import 'package:girinori/models/transit_model.dart';
import 'package:girinori/widgets/dashboard/route_timeline_card.dart';

class RoutePageView extends StatelessWidget {
  final List<TransitRoute> routes;
  final PageController pageController;
  final TimetableController timetableController;
  final LineController lineController;
  final String? widgetRouteId;

  final void Function(Offset globalPosition, int index, bool isWidgetRoute)
  onRouteMenu;

  const RoutePageView({
    super.key,
    required this.routes,
    required this.pageController,
    required this.timetableController,
    required this.lineController,
    required this.onRouteMenu,
    required this.widgetRouteId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: PageView.builder(
        controller: pageController,
        itemCount: routes.length,
        padEnds: false,
        itemBuilder: (context, index) {
          final route = routes[index];

          return Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 4.0, bottom: 4.0),
            child: GestureDetector(
              child: Stack(
                children: [
                  RouteTimelineCard(
                    route: route,
                    timetableController: timetableController,
                    lineController: lineController,
                    onRouteMenu: (globalPosition) {
                      onRouteMenu(
                        globalPosition,
                        index,
                        widgetRouteId == route.id,
                      );
                    },
                  ),

                  // ⭐ Widget表示中のルート
                  if (widgetRouteId == route.id)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(Icons.star, color: Colors.amber, size: 22),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
