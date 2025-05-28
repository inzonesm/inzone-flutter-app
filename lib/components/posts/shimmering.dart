// ignore_for_file: depend_on_referenced_packages, use_super_parameters, use_key_in_widget_constructors, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:skeleton_text/skeleton_text.dart';

class SkeletonContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final Color? color;
  final BorderRadius borderRadius;

  const SkeletonContainer._({
    this.width,
    this.height,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(0)),
    Key? key,
  }) : super(key: key);

  const SkeletonContainer.rounded({
    double? width,
    double? height,
    Color? color,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) : this._(
          width: width,
          height: height,
          color: color,
          borderRadius: borderRadius,
        );

  const SkeletonContainer.circular({
    double? width,
    double? height,
    Color? color,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(80)),
  }) : this._(
          width: width,
          height: height,
          color: color,
          borderRadius: borderRadius,
        );

  @override
  Widget build(BuildContext context) {
    return SkeletonAnimation(
      shimmerColor: color ?? Theme.of(context).canvasColor,
      borderRadius: borderRadius,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).canvasColor.withOpacity(0.5),
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

Widget PostLoading(BuildContext context) {
  return Stack(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Skelton(height: 320, width: MediaQuery.of(context).size.width),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽 Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonContainer.circular(
                        height: 40,
                        width: 40,
                      ),
                      SizedBox(width: 10),
                      SkeletonContainer.circular(
                        height: 40,
                        width: 200,
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  SkeletonContainer.rounded(
                    height: 180,
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      SkeletonContainer.circular(
                        height: 40,
                        width: 40,
                      ),
                      SizedBox(width: 10),
                      SkeletonContainer.circular(
                        height: 40,
                        width: 40,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// 광고 로딩을 위한 별도의 위젯
Widget AdPostLoading(BuildContext context) {
  return Stack(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Skelton(
          height: 320,
          width: MediaQuery.of(context).size.width,
          color: Theme.of(context).cardColor.withOpacity(0.7),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 광고 라벨
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SkeletonContainer.circular(
                  height: 30,
                  width: 60,
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
                const SizedBox(width: 10),
                const SkeletonContainer.circular(
                  height: 30,
                  width: 100,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 광고 이미지
            SkeletonContainer.rounded(
              height: 180,
              color: Theme.of(context).cardColor.withOpacity(0.9),
            ),
            const SizedBox(height: 15),
            // 광고 하단 버튼
            SkeletonContainer.rounded(
              height: 40,
              width: 120,
              color: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget CategoryLoading(BuildContext context) {
  return Stack(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Skelton(
          height: 40,
          width: MediaQuery.of(context).size.width,
          color: Colors.transparent,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(10, (index) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  height: 95,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SkeletonContainer.circular(
                        height: 75,
                        width: 75,
                        color: Theme.of(context).cardColor,
                      ),
                      const SizedBox(height: 10),
                      SkeletonContainer.circular(
                        height: 10,
                        width: 50,
                        color: Theme.of(context).cardColor,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      // Padding(
      //   padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
      //   child: SingleChildScrollView(
      //     scrollDirection: Axis.horizontal,
      //     child: Row(
      //       children: [
      //         SkeletonContainer.circular(
      //           height: 45,
      //           width: 100,
      //           color: Theme.of(context).cardColor,
      //         ),
      //         const SizedBox(width: 10),
      //         SkeletonContainer.circular(
      //           height: 45,
      //           width: 200,
      //           color: Theme.of(context).cardColor,
      //         ),
      //         const SizedBox(width: 10),
      //         SkeletonContainer.circular(
      //           height: 45,
      //           width: 120,
      //           color: Theme.of(context).cardColor,
      //         ),
      //       ],
      //     ),
      //   ),
      // ),
    ],
  );
}

Widget GroupLoading(BuildContext context) {
  return Stack(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Skelton(
          height: 40,
          width: MediaQuery.of(context).size.width,
          color: Colors.transparent,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SkeletonContainer.circular(
                height: 45,
                width: 100,
                color: Theme.of(context).cardColor,
              ),
              const SizedBox(width: 10),
              SkeletonContainer.circular(
                height: 45,
                width: 200,
                color: Theme.of(context).cardColor,
              ),
              const SizedBox(width: 10),
              SkeletonContainer.circular(
                height: 45,
                width: 120,
                color: Theme.of(context).cardColor,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget GroupCardLoading(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(4),
    child: Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title area
            SkeletonContainer.rounded(
              height: 60,
              width: double.infinity,
            ),
            SizedBox(height: 4),

            // Description area
            SkeletonContainer.rounded(
              height: 80,
              width: double.infinity,
            ),
            SizedBox(height: 8),

            // Stats row
            Row(
              children: [
                SkeletonContainer.circular(
                  height: 24,
                  width: 60,
                ),
                Spacer(),
                SkeletonContainer.circular(
                  height: 24,
                  width: 60,
                ),
              ],
            ),

            SizedBox(height: 16),

            // Avatar stack at bottom
            SkeletonContainer.circular(
              height: 40,
              width: 120,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget ImageLoading(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(4),
    child: Container(
      height: 140,
      width: 140,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SkeletonContainer.rounded(
        height: 140,
        width: 140,
        color: Theme.of(context).cardColor,
      ),
    ),
  );
}

Widget ImageLoading2(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(4),
    child: Container(
      height: 300,
      width: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SkeletonContainer.rounded(
        height: 300,
        width: 300,
        color: Theme.of(context).cardColor,
      ),
    ),
  );
}

class Skelton extends StatelessWidget {
  const Skelton({
    super.key,
    this.height,
    this.width,
    this.color,
  });
  final double? height, width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(
        bottom: 15.0,
      ),
    );
  }
}
