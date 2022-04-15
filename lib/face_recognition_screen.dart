// @dart=2.9
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:police_face_recognition/welcome_screen.dart';
import 'add_new_face_screen.dart';
import 'utils.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:progress_dialog/progress_dialog.dart';

void main() => runApp(RecognitionScreen());

////////////////////////////////////////////////////////////////
final baseTextStyle = const TextStyle(fontFamily: 'Poppins');

final headerTextStyle = baseTextStyle.copyWith(
    color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.w600);

final subHeaderTextStyle = regularTextStyle.copyWith(fontSize: 16.0);

final regularTextStyle = baseTextStyle.copyWith(
    color: const Color(0xffb6b2df),
    fontSize: 14.0,
    fontWeight: FontWeight.w400);
////////////////////////////////////////////////////////////////

class RecognitionScreen extends StatefulWidget {
  @override
  _RecognitionScreenState createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RecognitionScreen> {
  //Global Variables
  ProgressDialog progressDialog;
  User currentUser = FirebaseAuth.instance.currentUser;
  var imageFile;
  img.Image originalImage;
  List<Rect> rect = [];
  List<Map<String, int>> faceMaps = [];
  List croppedFaces = [];
  List allDocs = [];
  int nFaces;
  bool isFaceDetected = false;
  bool isFaceCropped = false;
  List<int> facesIndexes = [];
  var interpreter;
  final picker = ImagePicker();
  //End of the Global Variables

  Future loadModel() async {
    try {
      final gpuDelegateV2 = tfl.GpuDelegateV2(
          options: tfl.GpuDelegateOptionsV2(
        false,
        tfl.TfLiteGpuInferenceUsage.fastSingleAnswer,
        tfl.TfLiteGpuInferencePriority.minLatency,
        tfl.TfLiteGpuInferencePriority.auto,
        tfl.TfLiteGpuInferencePriority.auto,
      ));

      var interpreterOptions = tfl.InterpreterOptions()
        ..addDelegate(gpuDelegateV2);
      interpreter = await tfl.Interpreter.fromAsset('mobilefacenet.tflite',
          options: interpreterOptions);
    } on Exception {
      // _showDialog(context, "Error", "Failed to load model.");
      showError('Failed to load model');
      print('Failed to load model.');
    }
  }

  signOut() async {
    FirebaseAuth.instance.signOut();
    final googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();
  }

  Future<void> _showSelectionDialog(BuildContext context) {
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: Text("Take the photo from"),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    GestureDetector(
                      child: Row(children: <Widget>[
                        Icon(Icons.photo_library),
                        SizedBox(width: 10),
                        Text("Gallery"),
                      ]),
                      onTap: () async {
                        await pickImage(context, fromCamera: false);
                      },
                    ),
                    Padding(padding: EdgeInsets.all(8.0)),
                    GestureDetector(
                      child: Row(children: <Widget>[
                        Icon(Icons.camera_alt),
                        SizedBox(width: 10),
                        Text("Camera"),
                      ]),
                      onTap: () async {
                        await pickImage(context, fromCamera: true);
                      },
                    )
                  ],
                ),
              ));
        });
  }

  //This function is called when the camera button or the image icon is pressed
  Future pickImage(BuildContext context, {bool fromCamera}) async {
    try {
      Navigator.of(context).pop(); //to close the previous popup menu

      await progressDialog.show();
      progressDialog.update(message: "Getting Stored Faces From Firebase...");

      //Get the data every time image picked is clicked to keep the data up-to-date
      await FirebaseFirestore.instance
          .collection('faces')
          .get()
          .then((QuerySnapshot querySnapshot) {
        querySnapshot.docs.forEach((doc) {
          allDocs.add(doc);
        });
      });
      progressDialog.update(message: "Detecting Faces...");

      var awaitImage;
      if (fromCamera)
        awaitImage = await picker.getImage(source: ImageSource.camera);
      else
        awaitImage = await picker.getImage(source: ImageSource.gallery);

      if (awaitImage != null) {
        //If user already selected an image
        //Important to determine image width and height later on
        imageFile =
            await awaitImage.readAsBytes(); //convert the image into bytes
        imageFile = await decodeImageFromList(
            imageFile); //Create an image from the list of bytes

        faceMaps = []; //Empty the list every time the method is called
        if (rect.length > 0) {
          //if there is any rectangles on screen
          //remove the rectangles from screen whenever new image is selected
          rect = [];
        }
        setState(() {
          //UnDisplay the cropped faces at the beggining of every new selected image
          isFaceCropped = false;
        });
        //convert the selected image into a FirebaseVisionImage
        final visionImage = InputImage.fromFile(File(awaitImage.path));

        //get an instance of the Firebase faceDetector class
        final faceDetector = GoogleMlKit.vision.faceDetector();
        //send the image to be be processed
        //and save the detected faces into a list called "faces"
        final List<Face> faces = await faceDetector.processImage(visionImage);
        //get the number of faces detected and save it to the global variable "nFaces"
        //needed for the crop
        nFaces = faces.length;
        //decode the selected image and sets it to global var "originalImage"
        //this is needed in the cropped faces GridView
        originalImage =
            img.decodeImage(File(awaitImage.path).readAsBytesSync());
        //loop throw each detected face
        for (Face face in faces) {
          //add the bounding box details of the face to the "rect" list
          rect.add(face.boundingBox);
          //get the coordinates of the bounding box of the detected face
          int x = face.boundingBox.left.toInt();
          int y = face.boundingBox.top.toInt();
          int w = face.boundingBox.width.toInt();
          int h = face.boundingBox.height.toInt();
          //store the coordinates into a map for later use
          Map<String, int> thisMap = {'x': x, 'y': y, 'w': w, 'h': h};
          //add the coordinates to a global list "FaceMaps"
          //This list will contain all info for all the detected faces
          faceMaps.add(thisMap);
        } //end of the for loop
        setState(() {
          //at the end of the function set this to true
          //useful to determine when to start drawing the rectangles and so
          isFaceDetected = true;
        });

        await progressDialog.hide();
        //At the end of image select .. start cropping
        await cropFaces();
      }
    } catch (e) {
      await progressDialog.hide();
      showError(e.toString());
      print(e.toString());
    }
  }

  showError(String errorMessage) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('ERROR'),
            content: Text(errorMessage),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'))
            ],
          );
        });
  }

  Future cropFaces() async {
    try {
      croppedFaces = []; //Empty the list every time the crop button is pressed
      facesIndexes = []; //Empty the list that store indices of faces details

      //Load the Model every time face is cropped so it also at end of image selection
      //Not sure if it should be here or just put it in "initial state"for only once
      await loadModel();

      //loop throw the detected faces to crop them with the extracted info from before
      for (int counter = 0; counter < nFaces; counter++) {
        //Crop the "selected image" with the coordinates stored on "FaceMaps"
        //and repeat for every face using the "counter"
        img.Image faceCrop = img.copyCrop(
            originalImage,
            faceMaps[counter]['x'],
            faceMaps[counter]['y'],
            faceMaps[counter]['w'],
            faceMaps[counter]['h']);

        //resize for the model use
        faceCrop = img.copyResizeCropSquare(faceCrop, 112);

        //"facesIndexes" is a list of "Integers" that stores the index where we find
        // the details of the detected faces into global List for later use.
        facesIndexes.add(_faceRecognizer(faceCrop));

        //encode the cropped image
        //then add the cropped image into a global list called "CroppedFaces"
        //will be used later to display the cropped faces
        croppedFaces.add(img.encodePng(faceCrop));

        setState(() {
          //useful to determine when to start displaying the cropped faces
          isFaceCropped = true;
        });
      }

    } catch (e) {
      showError(e.toString());
      print(e);
    }
  }

  //The function that takes the current cropped image
  //and compare it to all face found on the firebase
  //return int that indicate the indices of the data to display

  int _faceRecognizer(img.Image img) {
    List input = imageToByteListFloat32(img, 112, 128, 128);
    input = input.reshape([1, 112, 112, 3]);
    List output = List(1 * 192).reshape([1, 192]);
    interpreter.run(input, output);
    output = output.reshape([192]);
    //List of "output" is the face features
    return facesCompare(List.from(output));
  }

  int facesCompare(List currEmb) {
    //value important in face compare level of recognition
    //the limit not to exceed when comparing two faces
    double threshold = 1.0;
    //The return of "-1" is an indicator of the "NOT RECOGNIZED" faces
    if (allDocs.length == 0) return -1;
    double minDist = 999; // min distance of current face to the compared face
    double currDist = 0.0;
    int docFaceIndex = -1; //Face index value that will be returned

    for (int i = 0; i < allDocs.length; i++) {
      currDist = euclideanDistance(allDocs[i]['FaceID'], currEmb);
      if (currDist <= threshold && currDist < minDist) {
        //important to find best match if the same person registers more than one face
        minDist = currDist;
        docFaceIndex = i;
      }
    }
    return docFaceIndex;
  }

  Future<void> _profileDialog() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.fromLTRB(0, 10, 0, 20),
          backgroundColor: Colors.white,
          content: Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 70,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Icon(
                      Icons.account_circle,
                      color: Color(0xff262254),
                      size: MediaQuery.of(context).size.width,
                    ),
                  ),
                ),
                //widget 2
                //make sure user is logged in
                currentUser != null
                    ?
                    //if user logged then display the "Email"
                    Text(
                        currentUser.email,
                        textAlign: TextAlign.center,
                        style: baseTextStyle,
                      )
                    :
                    //else if user is not logged then display the "No User Logged" text
                    Text('No User Logged !', textAlign: TextAlign.center),
                SizedBox(height: 10),
                //widget 3 --> the button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Container(
                    padding: EdgeInsets.only(top: 3, left: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),

                    ),
                    child: MaterialButton(
                      height: 50,
                      onPressed: () async {
                        await signOut();
                        // await FirebaseAuth.instance.signOut();
                        Navigator.pushReplacement(context,
                            MaterialPageRoute(builder: (context) => WelcomeScreen()));
                      },
                      color: Color(0xff262254),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout,
                            color: Colors.white,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Log Out",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20.0,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

////////////////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    progressDialog = ProgressDialog(context, type: ProgressDialogType.Normal);
    return Scaffold(
      ///////////////
      bottomNavigationBar: ConvexAppBar(
        backgroundColor: Color(0xFF222427),
        style: TabStyle.reactCircle,
        gradient: new LinearGradient(
          colors: [
            const Color((0xFF222427)),
            const Color(0xFF333366),
          ],
        ),
        items: [
          TabItem(icon: Icons.person_add, title: 'Add new faces'),
          TabItem(icon: Icons.add_a_photo, title: 'Pick Image'),
          TabItem(icon: Icons.account_circle, title: 'Account'),
        ],
        initialActiveIndex: 1,
        onTap: (int i) {
          switch (i) {
            case 0:
              {
                //Add new faces
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => AddNewFaceScreen()));
              }
              break;
            case 1:
              {
                _showSelectionDialog(context);
              }
              break;
            case 2:
              {
                _profileDialog();
              }
              break;
          }
        },
      ),
      ////////////////
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            children: <Widget>[
              //check if the face is detected to determine whether to draw the rectangles or not
              isFaceDetected
                  //if true
                  ? Container(
                      margin: EdgeInsets.fromLTRB(0, 0, 0, 20),
                      child: FittedBox(
                        child: SizedBox(
                          //fit hte image into the container using sizedBox and FittedBox
                          width: imageFile.width.toDouble(),
                          height: imageFile.height.toDouble(),
                          child: CustomPaint(
                            painter:
                                //paint the rectangles with the given info from the lists.
                                //using the "FacePainter" class
                                FacePainter(rect: rect, imageFile: imageFile),
                          ),
                        ),
                      ),
                    )
                  //if false draw placeholder
                  //visible at first run of the app
                  : InkWell(
                      onTap: () => _showSelectionDialog(context),
                      child: Icon(
                        Icons.image,
                        color: Color(0xFF333366),
                        size: MediaQuery.of(context).size.width,
                        // size: double.infinity,
                      ),
                    ),
              //second widget of the column
              //The dividers
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Color(0xFF222427),
                      height: 10,
                      thickness: 3,
                      indent: 10,
                      endIndent: 10,
                    ),
                  ),
                  Text(
                    "Detected Faces",
                    style: baseTextStyle,
                  ),
                  Expanded(
                    child: Divider(
                      color: Color(0xFF222427),
                      height: 10,
                      thickness: 3,
                      indent: 10,
                      endIndent: 10,
                    ),
                  ),
                ],
              ),
              //third widget of the column
              //check if the faces are cropped to determine whether to display them or not
              isFaceCropped
                  //if faces are cropped
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate:
                          //type of gridView is t determine the number of children on CrossAxis
                          SliverGridDelegateWithFixedCrossAxisCount(
                        //////////////////
                        mainAxisExtent: 160,
                        // crossAxisSpacing: 100,
                        //////////////////
                        // childAspectRatio: MediaQuery.of(context).size.width /
                        //     (MediaQuery.of(context).size.height / 4),
                        //////////////////
                        //count of items in each row
                        crossAxisCount: 1,
                      ),
                      //////////////////

                      //number of items that will be generated
                      //it is determined by the length of the "CroppedFaces" list
                      itemCount: croppedFaces.length,

                      //the item builder which contains the code that will be displayed on the gridview
                      //"index" variable loops throw the given items in the "itemCount"
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                            height: 120.0,
                            margin: const EdgeInsets.symmetric(
                              vertical: 16.0,
                              horizontal: 24.0,
                            ),
                            child: new Stack(
                              children: <Widget>[
                                //planetCard
                                new Container(
                                  height: 124.0,
                                  margin: new EdgeInsets.only(left: 46.0),
                                  decoration: new BoxDecoration(
                                    // Color(0xFF222427)
                                    color: new Color(0xFF333366),
                                    // color: new Color(0xFF222427),
                                    shape: BoxShape.rectangle,
                                    borderRadius:
                                        new BorderRadius.circular(8.0),
                                    boxShadow: <BoxShadow>[
                                      new BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 10.0,
                                        offset: new Offset(0.0, 10.0),
                                      ),
                                    ],
                                  ),
                                ),
                                // planetCardContent,
                                new Container(
                                  // margin: new EdgeInsets.fromLTRB(76.0, 16.0, 16.0, 16.0),
                                  margin: new EdgeInsets.fromLTRB(
                                      120.0, 10.0, 16.0, 10.0),
                                  constraints: new BoxConstraints.expand(),
                                  child: new Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      new Container(height: 4.0),
                                      facesIndexes[index] != -1
                                          ? Text(
                                              allDocs[facesIndexes[index]]
                                                      ['name']
                                                  .toUpperCase(),
                                              style: headerTextStyle,
                                            )
                                          : Text(
                                              "NOT RECOGNIZED",
                                              // textAlign: TextAlign.center,
                                              style: headerTextStyle,
                                            ),
                                      new Container(height: 5.0),
                                      facesIndexes[index] != -1
                                          ? Text(
                                              allDocs[facesIndexes[index]]
                                                      ['status']
                                                  .toUpperCase(),
                                              style: subHeaderTextStyle)
                                          : Text('UNKNOWN STATUS',
                                              style: subHeaderTextStyle),
                                      new Container(
                                          margin: new EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          height: 2.0,
                                          width: 50.0,
                                          color: new Color(0xff00c6ff)),
                                      new Container(width: 8.0),
                                      facesIndexes[index] != -1
                                          ? Text(
                                              allDocs[facesIndexes[index]]
                                                      ['age'] +
                                                  " Years Old.",
                                              style: regularTextStyle)
                                          : Text(""),
                                    ],
                                  ),
                                ),
                                // planetThumbnail,
                                new Container(
                                  margin:
                                      new EdgeInsets.symmetric(vertical: 16.0),
                                  alignment: FractionalOffset.centerLeft,
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: CircleAvatar(
                                      backgroundImage:
                                          MemoryImage(croppedFaces[index]),
                                      radius: 50,
                                    ),
                                  ),
                                ),
                              ],
                            ));
                      })
                  //if faces are not yet cropped
                  //then display empty container
                  : Container(),
            ],
          ),
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  List<Rect> rect;
  var imageFile;

  //constructor that requires two parameters
  //requires the list of info of the coordinates of the bounding boxs
  //requires the image that will display the rectangles on
  //sets all that to the variables on this class
  FacePainter({@required this.rect, @required this.imageFile});

  @override
  void paint(Canvas canvas, Size size) {
    //makes sure that an image is selected
    if (imageFile != null) {
      //Draw the image on the screen
      canvas.drawImage(imageFile, Offset.zero, Paint());
    }

    //loop throw the coordinates of the bounding box
    for (Rect rectangle in rect) {
      //draws rectangle with customized options
      canvas.drawRect(
        rectangle,
        Paint()
          ..color = Colors.green
          ..strokeWidth = 10.0
          ..style = PaintingStyle.stroke,
      );
    }
  }

  //This is called every time new information is represented to the instance of the class
  //meaning that the rectangles is repainted with every new picked image
  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
