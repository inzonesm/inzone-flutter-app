// import 'dart:async';
// import 'dart:math';
//
// import 'package:flutter/material.dart';
// import 'package:images_picker/images_picker.dart';
// import 'package:lottie/lottie.dart';
//
// class LottieWithTimer extends StatefulWidget {
//   final VoidCallback onTimerEnd;
//   String? url;
//    LottieWithTimer({super.key, required this.onTimerEnd, required this.url});
//
//   @override
//   State<LottieWithTimer> createState() => _LottieWithTimerState();
// }
//
// class _LottieWithTimerState extends State<LottieWithTimer> {
//   bool showLottie = true;
//
//   List<String> links = [
//     'https://plus.unsplash.com/premium_photo-1682124669726-6721b5a1932c?q=80&w=2970&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
//     'https://images.unsplash.com/photo-1578632749014-ca77efd052eb?q=80&w=2940&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
//     'https://images.unsplash.com/photo-1634580285846-374f22b48c7d?q=80&w=2832&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
//     'https://plus.unsplash.com/premium_vector-1682269956903-9c70bc8f3b51?q=80&w=2960&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
//     'https://plus.unsplash.com/premium_vector-1721131163268-d897f51d989f?q=80&w=2960&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
//     'https://plus.unsplash.com/premium_vector-1721131162449-5676bedcd9a2?q=80&w=2960&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
//     'https://plus.unsplash.com/premium_vector-1721631720571-fe9fc3f161f7?q=80&w=2960&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
//     'https://plus.unsplash.com/premium_vector-1720532759256-46006d8c6c2e?q=80&w=2998&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
//     'https://plus.unsplash.com/premium_vector-1682269287900-d96e9a6c188b?q=80&w=2960&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
//     'https://plus.unsplash.com/premium_vector-1721637089678-0042adca08a3?q=80&w=2960&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
//     'https://plus.unsplash.com/premium_vector-1721637089678-0042adca08a3?q=80&w=2960&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
//     'https://plus.unsplash.com/premium_vector-1721148066971-873367981f82?q=80&w=2960&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D'
//   ];
//   // Create a Random object
//   Random random = Random();
//
//   @override
//   void initState() {
//     super.initState();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return widget.url == null ?
//   }
// }