// @dart=2.9
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:progress_dialog/progress_dialog.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  ProgressDialog progressDialog;
  FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isObscure = true;

  String _name, _email, _password;

  @override
  void initState() {
    super.initState();
  }

  signUp() async {
    if (_formKey.currentState.validate()) {
      await progressDialog.show();

      _formKey.currentState.save();

      try {
        UserCredential user = await _auth.createUserWithEmailAndPassword(
            email: _email, password: _password);

        if (user != null) {
          await progressDialog.hide();

          await _showDialog(context, 'Done', 'User Created Successfully');
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => LoginScreen()));
        }
      } catch (e) {
        await progressDialog.hide();
        showError(e.message);
        print(e);
      }
    }
  }

  Future<void> _showDialog(BuildContext context, title, content) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
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

  String _validateEmail(String value) {
    value = value.trim();

    if (value.isEmpty) {
      return 'Email can\'t be empty';
    } else if (!value.contains(RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+"))) {
      return 'Enter a correct email address';
    }
    return null;
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
        body: Container(
          height: MediaQuery.of(context).size.height,
          width: double.infinity,
          child: Column(
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        Text(
                          "Sign up",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        Text(
                          "Create an account, It's free ",
                          style:
                              TextStyle(fontSize: 15, color: Colors.grey[700]),
                        )
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: <Widget>[


                            Container(
                              child: TextFormField(
                                  validator: (input) {
                                    if (input.isEmpty) return 'Enter a name';
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 0, horizontal: 10),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide:
                                      BorderSide(color: Colors.grey[400]),
                                    ),
                                    border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Colors.grey[400])),
                                    labelText: 'Name',
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                  onSaved: (input) => _name = input),
                            ),
                            SizedBox(height: 20),
                            Container(
                              child: TextFormField(
                                  validator: (input) {
                                    if (input.isEmpty) return 'Enter a company ';
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 0, horizontal: 10),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide:
                                      BorderSide(color: Colors.grey[400]),
                                    ),
                                    border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Colors.grey[400])),
                                    labelText: 'company',
                                    prefixIcon: Icon(Icons.home_work),
                                  ),
                                  onSaved: (input) => _name = input),
                            ),
                            SizedBox(height: 20),
                            Container(
                              child: TextFormField(
                                  validator: (input) {
                                    if (input.isEmpty) return 'Enter a jop title ';
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 0, horizontal: 10),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide:
                                      BorderSide(color: Colors.grey[400]),
                                    ),
                                    border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Colors.grey[400])),
                                    labelText: 'jop title',
                                    prefixIcon: Icon(Icons.work),
                                  ),
                                  onSaved: (input) => _name = input),
                            ),
                            SizedBox(height: 20),
                            Container(
                              child: TextFormField(
                                  validator: (input) {
                                    if (input.isEmpty) return 'Enter a National ID ';
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 0, horizontal: 10),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide:
                                      BorderSide(color: Colors.grey[400]),
                                    ),
                                    border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Colors.grey[400])),
                                    labelText: 'National ID',
                                    prefixIcon: Icon(Icons.perm_identity),
                                  ),
                                  onSaved: (input) => _name = input),
                            ),
                            SizedBox(height: 20),
                            Container(
                              child: TextFormField(
                                  validator: _validateEmail,
                                  decoration: InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 0, horizontal: 10),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.grey[400]),
                                      ),
                                      border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                              color: Colors.grey[400])),
                                      labelText: 'Email',
                                      prefixIcon: Icon(Icons.email)),
                                  onSaved: (input) => _email = input),
                            ),
                            SizedBox(height: 25),
                            Container(
                              child: TextFormField(
                                  validator: (input) {
                                    if (input.length < 6)
                                      return 'Provide Minimum 6 Character';
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 0, horizontal: 10),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.grey[400]),
                                    ),
                                    border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Colors.grey[400])),
                                    labelText: 'Password',
                                    prefixIcon: IconButton(
                                      icon: Icon(Icons.lock),
                                    ),
                                    suffixIcon: Row(
                                      mainAxisSize:
                                          MainAxisSize.min, // added line
                                      children: <Widget>[
                                        IconButton(
                                            icon: Icon(_isObscure
                                                ? Icons.visibility
                                                : Icons.visibility_off),
                                            onPressed: () {
                                              setState(() {
                                                _isObscure = !_isObscure;
                                              });
                                            }),
                                      ],
                                    ),
                                  ),
                                  obscureText: _isObscure,
                                  onSaved: (input) => _password = input),
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      children: [
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
                              onPressed: signUp,
                              color: Color(0xFF1565C0),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                "SignUp",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 15,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text("Already have an account?"),
                            TextButton(
                                child: Text(
                                  " Login",
                                  style: TextStyle(
                                      color: Color(0xFF1565C0),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18),
                                ),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => LoginScreen()));
                                }),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}
