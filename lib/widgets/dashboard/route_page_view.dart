import 'package:flutter/material.dart';
import 'package:girinori/controllers/timetable_controller.dart';
import 'package:girinori/models/transit_model.dart';
import 'package:girinori/widgets/dashboard/route_timeline_card.dart';

class RoutePageView extends StatelessWidget {
  final List<TransitRoute> routes;
  final Map<String, TimeOfDay> routeBaseTimes;
  final Map<String, int> segmentShiftCounts;
  final PageController pageController;
  final TimetableController timetableController;

  final void Function(int index) onEditRoute;
  final void Function(String routeId, int segmentIndex, bool isNext)
  onShiftTrain;

  const RoutePageView({
    super.key,
    required this.routes,
    required this.routeBaseTimes,
    required this.segmentShiftCounts,
    required this.pageController,
    required this.timetableController,
    required this.onEditRoute,
    required this.onShiftTrain,
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
              onTap: () => onEditRoute(index),
              child: RouteTimelineCard(
                route: route,
                baseTime: routeBaseTimes[route.id] ?? TimeOfDay.now(),
                timetableController: timetableController,
                segmentShiftCounts: segmentShiftCounts,
                onShiftTrain: (segmentIndex, isNext) {
                  onShiftTrain(route.id, segmentIndex, isNext);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
