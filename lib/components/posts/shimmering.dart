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
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 0, horizontal: 20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SkeletonContainer.circular(
                height: 45,
                width: 100,
                color: Colors.white,
              ),
              SizedBox(width: 10),
              SkeletonContainer.circular(
                height: 45,
                width: 200,
                color: Colors.white,
              ),
              SizedBox(width: 10),
              SkeletonContainer.circular(
                height: 45,
                width: 120,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    ],
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
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(
        bottom: 15.0,
      ),
    );
  }
}
