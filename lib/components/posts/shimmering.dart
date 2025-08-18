// ignore_for_file: depend_on_referenced_packages, use_super_parameters, use_key_in_widget_constructors, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:skeleton_text/skeleton_text.dart';
import 'package:shimmer/shimmer.dart';

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
            SkeletonContainer.rounded(
              height: 180,
              color: Theme.of(context).cardColor.withOpacity(0.9),
            ),
            const SizedBox(height: 15),
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
      height: 130,
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
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SkeletonContainer.rounded(
                    height: 10,
                  ),
                ),
                SizedBox(width: 12),
                SkeletonContainer.rounded(
                  height: 10,
                  width: 30,
                ),
                SizedBox(width: 8),
                SkeletonContainer.rounded(
                  height: 10,
                  width: 30,
                ),
                SizedBox(width: 8),
                SkeletonContainer.rounded(
                  height: 10,
                  width: 30,
                ),
              ],
            ),
            SizedBox(height: 12),
            SkeletonContainer.rounded(
              height: 12,
              width: double.infinity,
            ),
            SizedBox(height: 12),
            SkeletonContainer.rounded(
              height: 48,
              width: double.infinity,
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
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SkeletonContainer.rounded(
        height: 140,
        width: MediaQuery.of(context).size.width,
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

Widget AvatarLoading(BuildContext context) {
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

Widget SearchLoading(BuildContext context) {
  return CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SkeletonContainer.rounded(
                width: 120,
                height: 24,
                color: Theme.of(context).cardColor,
              ),
              const Spacer(),
              SkeletonContainer.rounded(
                width: 60,
                height: 24,
                color: Theme.of(context).cardColor,
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 130,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 8,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).cardColor,
                              Theme.of(context).cardColor.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2.5),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).cardColor,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: ClipOval(
                                child: SkeletonContainer.circular(
                                  width: 75,
                                  height: 75,
                                  color: Theme.of(context)
                                      .cardColor
                                      .withOpacity(0.7),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SkeletonContainer.rounded(
                        width: 60,
                        height: 12,
                        color: Theme.of(context).cardColor.withOpacity(0.7),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonContainer.rounded(
                width: 150,
                height: 24,
                color: Theme.of(context).cardColor,
              ),
              SkeletonContainer.rounded(
                width: 70,
                height: 20,
                color: Theme.of(context).cardColor,
              ),
            ],
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
              child: Row(
                children: [
                  SkeletonContainer.circular(
                    width: 20,
                    height: 20,
                    color: Theme.of(context).cardColor,
                  ),
                  const SizedBox(width: 16),
                  SkeletonContainer.rounded(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 16,
                    color: Theme.of(context).cardColor,
                  ),
                  const Spacer(),
                  SkeletonContainer.circular(
                    width: 20,
                    height: 20,
                    color: Theme.of(context).cardColor,
                  ),
                ],
              ),
            );
          },
          childCount: 3,
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: SkeletonContainer.rounded(
            width: 180,
            height: 24,
            color: Theme.of(context).cardColor,
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
              child: PostLoading(context),
            );
          },
          childCount: 3,
        ),
      ),
    ],
  );
}

Widget ProfileShimmering(BuildContext context, bool isAI) {
  return SingleChildScrollView(
    child: Column(
      children: [
        Container(
          color: Theme.of(context).cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: Theme.of(context).canvasColor,
                  ),
                  Positioned(
                    left: 16,
                    bottom: -40,
                    child: SkeletonContainer.rounded(
                      width: 80,
                      height: 80,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color.fromARGB(255, 44, 44, 44)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SkeletonContainer.rounded(
                      width: 80,
                      height: 35,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color.fromARGB(255, 44, 44, 44)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(17),
                    ),
                    const SizedBox(width: 12),
                    SkeletonContainer.rounded(
                      width: 100,
                      height: 35,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color.fromARGB(255, 44, 44, 44)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Content row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Padding(
                          padding: const EdgeInsets.only(left: 24, right: 0),
                          child: SkeletonContainer.rounded(
                            width: 150,
                            height: 24,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color.fromARGB(255, 44, 44, 44)
                                    : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Bio
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: SkeletonContainer.rounded(
                            width: double.infinity,
                            height: 40,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color.fromARGB(255, 44, 44, 44)
                                    : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Stats row
                        Padding(
                          padding: const EdgeInsets.only(left: 24, right: 0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Posts stat
                              Row(
                                children: [
                                  SkeletonContainer.rounded(
                                    width: 30,
                                    height: 20,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color.fromARGB(255, 44, 44, 44)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  const SizedBox(width: 5),
                                  SkeletonContainer.rounded(
                                    width: 35,
                                    height: 16,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color.fromARGB(255, 44, 44, 44)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 20),
                              // Following stat
                              Row(
                                children: [
                                  SkeletonContainer.rounded(
                                    width: 30,
                                    height: 20,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color.fromARGB(255, 44, 44, 44)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  const SizedBox(width: 5),
                                  SkeletonContainer.rounded(
                                    width: 55,
                                    height: 16,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color.fromARGB(255, 44, 44, 44)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 20),
                              // Followers stat
                              Row(
                                children: [
                                  SkeletonContainer.rounded(
                                    width: 30,
                                    height: 20,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color.fromARGB(255, 44, 44, 44)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  const SizedBox(width: 5),
                                  SkeletonContainer.rounded(
                                    width: 55,
                                    height: 16,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color.fromARGB(255, 44, 44, 44)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        if (!isAI)
                          SizedBox(
                            height: 70,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(left: 20.0),
                              itemCount: 6, // Number of skeleton items to show
                              itemBuilder: (context, index) {
                                return Container(
                                  width: 60,
                                  margin: const EdgeInsets.only(right: 12.0),
                                  child: Column(
                                    children: [
                                      SkeletonContainer.rounded(
                                        width: 50,
                                        height: 50,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color.fromARGB(
                                                255, 44, 44, 44)
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      const SizedBox(height: 8),
                                      SkeletonContainer.rounded(
                                        width: 40,
                                        height: 12,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color.fromARGB(
                                                255, 44, 44, 44)
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Posts shimmer
        Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Skelton(
                  height: 320, width: MediaQuery.of(context).size.width),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SkeletonContainer.circular(
                              height: 40,
                              width: 40,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color.fromARGB(255, 44, 44, 44)
                                  : Colors.grey[200],
                            ),
                            const SizedBox(width: 10),
                            SkeletonContainer.circular(
                              height: 40,
                              width: 200,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color.fromARGB(255, 44, 44, 44)
                                  : Colors.grey[200],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SkeletonContainer.rounded(
                          height: 180,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color.fromARGB(255, 44, 44, 44)
                              : Colors.grey[200],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            SkeletonContainer.circular(
                              height: 40,
                              width: 40,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color.fromARGB(255, 44, 44, 44)
                                  : Colors.grey[200],
                            ),
                            const SizedBox(width: 10),
                            SkeletonContainer.circular(
                              height: 40,
                              width: 40,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color.fromARGB(255, 44, 44, 44)
                                  : Colors.grey[200],
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
        ),
      ],
    ),
  );
}

Widget SearchResultsLoading(BuildContext context) {
  return ListView.builder(
    itemCount: 5,
    itemBuilder: (context, index) {
      return PostLoading(context);
    },
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
