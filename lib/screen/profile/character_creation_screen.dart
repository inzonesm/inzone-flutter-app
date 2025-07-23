import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inzone/services/inzone_database.dart';
import 'package:inzone/services/shared_preferences_helper_class.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';

class CharacterCreationScreen extends StatefulWidget {
  const CharacterCreationScreen({super.key});

  @override
  State<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  List<String> _savedList = [];
  String? url;
  late DateTime _startTime; // To store the start time
  int pageOpened = 0;
  bool nameSubmitted = false;
  bool success = false;
  TextEditingController nameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  bool onLastPage = false;
  bool timerOver = false;
  bool showLoading = false;
  bool showFields = true;

  @override
  void dispose() {
    DateTime endTime = DateTime.now().toUtc();
    Duration timeSpent = endTime.difference(_startTime);
    InZoneDatabase.logEvent('character_creation_screen',
        {"timeSpent": timeSpent.inSeconds, "pageOpenedCount": pageOpened});
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _startTime = DateTime.now().toUtc();
    pageOpened += 1;
  }

  Future<void> _loadPreferences() async {
    List<String>? list = await SharedPreferencesHelperClass.getStringList();
    setState(() {
      _savedList = list ?? [];
    });
  }

  Future<void> _savePreferences(List<String> list) async {
    await SharedPreferencesHelperClass.saveStringList(list);
    setState(() {
      _savedList = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: AnimatedContainer(
          duration: const Duration(seconds: 1),
          padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20))),
          child: Scaffold(
              backgroundColor: Theme.of(context).canvasColor,
              body: Padding(
                  padding:
                      const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(
                            left: 6.0,
                            right: 6.0,
                            top: 6.0,
                          ),
                          child: Center(
                            child: Text(
                              " Create a character!",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        // SizedBox(height: 10,),
                        const SizedBox(
                          height: 30,
                        ),
                        Visibility(
                            visible: showLoading,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              height: 500,
                              width: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.5),
                                    Theme.of(context).canvasColor
                                  ],
                                  radius: 0.5,
                                  center: const Alignment(0.0, 0.0),
                                  stops: const [0.0, 1.0],
                                ),
                              ),
                              child: Column(
                                children: [
                                  Lottie.asset(
                                      'assets/animations/animation_intro.json',
                                      height: 200,
                                      width: 200),
                                  const Center(
                                    child: Text(
                                      "Designing a brand new character for you...",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        url != null
                            ? Visibility(
                                visible: !showLoading,
                                child: SizedBox(
                                  width: MediaQuery.of(context).size.width - 60,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      url!,
                                      fit: BoxFit.fitWidth,
                                      color: null, // Remove any color overlay
                                      colorBlendMode: BlendMode
                                          .srcOver, // Use default blend mode
                                      errorBuilder: (context, object, st) {
                                        return const Text("error");
                                      },
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                        !showFields
                            ? const SizedBox()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Character Name",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width,
                                    height: 80,
                                    child: TextField(
                                      maxLines:
                                          1, // Set maxLines to null for multiline
                                      textInputAction: TextInputAction.done,
                                      controller: nameController,
                                      textAlign: TextAlign.left,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(18.0),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(18.0),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade900),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(18.0),
                                          borderSide: const BorderSide(
                                              color: Colors.blue),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 8.0,
                                        ),
                                        // labelText: 'What do you want you talk about?',
                                        //
                                        // labelStyle: TextStyle(color: Colors.grey.shade900),
                                        hintText: 'Name your character',

                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    "Character Description",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width,
                                    height: 150,
                                    child: TextField(
                                        minLines: 1,
                                        controller: descriptionController,
                                        maxLines:
                                            6, // Set maxLines to null for multiline
                                        textInputAction: TextInputAction.done,
                                        textAlign: TextAlign.left,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18.0),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18.0),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade900),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18.0),
                                            borderSide: const BorderSide(
                                                color: Colors.blue),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                            vertical: 8.0,
                                          ),
                                          // labelText: 'What do you want you talk about?',
                                          //
                                          // labelStyle: TextStyle(color: Colors.grey.shade900),
                                          hintText:
                                              'Name: Junior\nGender: Male\nAge: 14\nEye Color: Hazel\nLikes: Sports, Streaming and Gaming',

                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        )),
                                  ),
                                ],
                              ),
                        const Spacer(
                          flex: 2,
                        ),
                        !showFields
                            ? Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Flexible(
                                    child: ElevatedButton(
                                        onPressed: () async {
                                          setState(() {
                                            showLoading = true;
                                          });
                                          url = await InZoneDatabase
                                              .generateImage(
                                                  descriptionController.text);

                                          setState(() {
                                            showLoading = false;
                                          });
                                        },
                                        child: const Text(
                                          "Regenerate",
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                        )),
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  Flexible(
                                    child: ElevatedButton(
                                        onPressed: () {
                                          context.pop();
                                        },
                                        style: ElevatedButton.styleFrom(
                                            elevation: 10,
                                            backgroundColor: Colors.blue,
                                            disabledBackgroundColor:
                                                Colors.blue,
                                            //elevation of button
                                            shape: RoundedRectangleBorder(
                                                //to set border radius to button
                                                borderRadius:
                                                    BorderRadius.circular(60)),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10)),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            "Save",
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                          ),
                                        )),
                                  ),
                                ],
                              )
                            : Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 60.0),
                                child: ElevatedButton(
                                    onPressed: () async {
                                      // Navigator.push(
                                      //     context,
                                      //     MaterialPageRoute(
                                      //         builder: (context) => const InformationPages()));

                                      if (nameController.text.isNotEmpty) {
                                        _savedList.add(nameController.text);
                                        _savePreferences(_savedList);
                                        setState(() {
                                          showLoading = true;
                                          showFields = false;
                                        });

                                        url = await InZoneDatabase
                                            .generateImage(descriptionController
                                                    .text.isEmpty
                                                ? "No description given by user"
                                                : descriptionController.text);
                                        if (kDebugMode) {
                                          print(url);
                                        }
                                        if (url != null) {
                                          await InZoneDatabase.createCharacter(
                                                  nameController.text,
                                                  descriptionController.text,
                                                  url!)
                                              .whenComplete(() {
                                            setState(() {
                                              nameSubmitted = true;

                                              timerOver = true;
                                              showLoading = false;
                                            });
                                          });
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                        elevation: 10,
                                        backgroundColor: Colors.blue,
                                        disabledBackgroundColor: Colors.grey,
                                        //elevation of button
                                        shape: RoundedRectangleBorder(
                                            //to set border radius to button
                                            borderRadius:
                                                BorderRadius.circular(60)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 60, vertical: 20)),
                                    child: const Text(
                                      "Create my character",
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    )),
                              ),
                        const Spacer()
                      ])))),
    );
  }
}
