// @dart=2.9
import 'package:flutter/material.dart';
import 'package:progress_dialog/progress_dialog.dart';
import 'dart:io';
import 'utils.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

class AddNewFaceScreen extends StatefulWidget {
  @override
  _AddNewFaceScreenState createState() => _AddNewFaceScreenState();
}

class _AddNewFaceScreenState extends State<AddNewFaceScreen> {
  //Global variables
  ProgressDialog progressDialog;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  var interpreter;
  img.Image displayImage;
  List croppedFaces = [];
  String dropdownValue = 'Not Criminal';
  TextEditingController _nameController = TextEditingController();
  TextEditingController _ageController = TextEditingController();

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
      print('Failed to load model.');
    }
  }

  List _createFaceFeatures(img.Image img) {
    List input = imageToByteListFloat32(img, 112, 128, 128);
    input = input.reshape([1, 112, 112, 3]);
    List output = List(1 * 192).reshape([1, 192]);
    interpreter.run(input, output);
    output = output.reshape([192]);

    return List.from(output);
  }

  Future<void> _selectFaceDialog() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'SELECT A FACE',
            textAlign: TextAlign.center,
          ),
          content: Container(
            height: 135.0 * (croppedFaces.length ~/ 2),
            width: MediaQuery.of(context).size.width,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
              itemCount: croppedFaces.length,
              itemBuilder: (BuildContext context, int index) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      displayImage = croppedFaces[index];
                    });
                    Navigator.of(context).pop();
                  },
                  child: Card(
                    elevation: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 50,
                      backgroundImage:
                          MemoryImage(img.encodePng(croppedFaces[index])),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDialog(title, content) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, textAlign: TextAlign.center),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  _addData() async {
    if (_formKey.currentState.validate() && displayImage != null) {
      await progressDialog.show();

      try {
        progressDialog.update(message: "Loading Model...");
        await loadModel();
        progressDialog.update(message: "Extracting Face Features...");
        List _faceID = _createFaceFeatures(displayImage);

        progressDialog.update(message: "Uploading data to Firebase...");
        await FirebaseFirestore.instance.collection('faces').doc().set({
          "name": _nameController.text,
          "age": _ageController.text,
          "status": dropdownValue,
          "FaceID": _faceID,
        });

        await progressDialog.hide();

        await _showDialog('Done', 'New Face Added To The Database');
        Navigator.of(context).pop();
      } catch (e) {
        await progressDialog.hide();
        // showError(e.message);
        _showDialog("Error", e.message);
        print(e);
      }
    } else {
      await progressDialog.hide();
      _showDialog("Missing data", "Please select a face first");
    }
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
                      onTap: () {
                        _pickImage(context, fromCamera: false);
                      },
                    ),
                    Padding(padding: EdgeInsets.all(8.0)),
                    GestureDetector(
                      child: Row(children: <Widget>[
                        Icon(Icons.camera_alt),
                        SizedBox(width: 10),
                        Text("Camera"),
                      ]),
                      onTap: () {
                        // _openCamera(context);
                        _pickImage(context, fromCamera: true);
                      },
                    )
                  ],
                ),
              ));
        });
  }

  Future _pickImage(BuildContext context, {bool fromCamera}) async {
    try {
      croppedFaces = [];
      Navigator.of(context).pop(); //to close the previous popup menu

      await progressDialog.show();
      progressDialog.update(message: "Detecting Faces...");

      var picture;
      if (fromCamera) {
        picture = await picker.getImage(source: ImageSource.camera);
      } else {
        picture = await picker.getImage(source: ImageSource.gallery);
      }

      if (picture != null) {
        //convert the selected image into a FirebaseVisionImage
        final visionImage = InputImage.fromFile(File(picture.path));
        //get an instance of the Firebase faceDetector class
        final faceDetector = GoogleMlKit.vision.faceDetector();
        //send the image to be processed
        //and save the detected faces into a list called "faces"
        final List<Face> faces = await faceDetector.processImage(visionImage);
        //decode the selected image and sets it to var "originalImage"
        img.Image originalImage =
            img.decodeImage(File(picture.path).readAsBytesSync());

        img.Image faceCrop;
        //Store Cropped faces into "faceMaps"
        for (int i = 0; i < faces.length; i++) {
          faceCrop = img.copyCrop(
            originalImage,
            faces[i].boundingBox.left.toInt(),
            faces[i].boundingBox.top.toInt(),
            faces[i].boundingBox.width.toInt(),
            faces[i].boundingBox.height.toInt(),
          );
          faceCrop = img.copyResizeCropSquare(faceCrop, 112);
          croppedFaces.add(faceCrop);
        }
        // if there is only one face detected then display it
        if (faces.length == 1) {
          setState(() {
            displayImage = faceCrop;
          });
          await progressDialog.hide();
        } else
          await progressDialog.hide();
        //prompt user to choose from the detected faces
        await _selectFaceDialog();
      } else
        await progressDialog.hide();
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

  Widget _setImageView() {
    if (displayImage != null) {
      return InkWell(
        onTap: () {
          _showSelectionDialog(context);
        },
        child: CircleAvatar(
          backgroundColor: Colors.white,
          radius: 100,
          backgroundImage: MemoryImage(img.encodePng(displayImage)),
        ),
      );
    } else {
      return InkWell(
        onTap: () {
          _showSelectionDialog(context);
        },
        child: CircleAvatar(
          backgroundColor: Color(0xFF333366),
          radius: 100,
          child: FittedBox(
            child: Icon(
              Icons.tag_faces,
              // color: Color(0xFF6F35A5),
              color: Colors.white,
              size: MediaQuery.of(context).size.width,
            ),
          ),
        ),
      );
    }
  }

  Widget _inputFiled({label, controller, keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.black87)),
        SizedBox(height: 5),
        TextFormField(
          keyboardType: keyboardType,
          controller: controller,
          validator: _checkEmptyValidator,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[400]),
            ),
            border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[400])),
          ),
        ),
        SizedBox(height: 10),
      ],
    );
  }

  String _checkEmptyValidator(value) {
    if (value.isEmpty) {
      return "Input Required";
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    progressDialog = ProgressDialog(context, type: ProgressDialogType.Normal);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        brightness: Brightness.light,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: Colors.black,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF333366),
        onPressed: () {
          _showSelectionDialog(context);
        },
        child: Icon(Icons.camera_alt),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: double.infinity,
        child: Column(
          children: <Widget>[
            _setImageView(),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: <Widget>[
                          _inputFiled(
                            keyboardType: TextInputType.name,
                            controller: _nameController,
                            label: 'Name',
                          ),
                          _inputFiled(
                            keyboardType: TextInputType.number,
                            controller: _ageController,
                            label: 'Age',
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        Text('Status:',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Colors.black87)),
                        SizedBox(
                          width: 30,
                        ),
                        DropdownButton<String>(
                          value: dropdownValue,
                          onChanged: (String newValue) {
                            setState(() {
                              dropdownValue = newValue;
                            });
                          },
                          icon: Icon(
                            Icons.arrow_drop_down_circle_outlined,
                          ),
                          iconSize: 20,
                          underline: Container(
                            height: 2,
                            color: Colors.grey[400],
                          ),
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Colors.black87),
                          items: <String>['Not Criminal', 'Criminal']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Container(
                      padding: EdgeInsets.only(top: 3, left: 3),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                         ),
                      child: MaterialButton(
                        minWidth: double.infinity,
                        height: 50,
                        onPressed: _addData,
                        // color: Color(0xff0095FF),
                        color: Color(0xFF333366),

                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          "Add Data",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
