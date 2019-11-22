import 'dart:ffi';

import 'package:dart_objc/src/common/pointer_encoding.dart';
import 'package:dart_objc/src/foundation/gcd.dart';
import 'package:dart_objc/src/runtime/id.dart';
import 'package:dart_objc/src/runtime/native_runtime.dart';
import 'package:dart_objc/src/runtime/nsobject.dart';
import 'package:dart_objc/src/runtime/selector.dart';
import 'package:ffi/ffi.dart';

Pointer<Void> _msgSend(Pointer<Void> target, Pointer<Void> selector,
    Pointer<Void> signature, Pointer<Pointer<Void>> args, DispatchQueue queue) {
  Pointer<Void> result;
  Pointer<Void> queuePtr = queue != null ? queue.pointer : nullptr;
  // TODO: This awful code dues to this issue: https://github.com/dart-lang/sdk/issues/39488
  if (args != null && queuePtr != nullptr) {
    result = nativeInvokeMethod(target, selector, signature, queuePtr, args);
  } else if (args != null) {
    result = nativeInvokeMethodNoQueue(target, selector, signature, args);
  } else if (queuePtr != nullptr) {
    result = nativeInvokeMethodNoArgs(target, selector, signature, queuePtr);
  } else {
    result = nativeInvokeMethodNoArgsNorQueue(target, selector, signature);
  }
  return result;
}

dynamic msgSend(id target, Selector selector,
    [List args, bool auto = true, DispatchQueue queue]) {
  if (target == nil) {
    return null;
  }

  Pointer<Pointer<Utf8>> typeEncodingsPtrPtr =
      allocate<Pointer<Utf8>>(count: (args?.length ?? 0) + 1);
  Pointer<Void> selectorPtr = selector.toPointer();

  Pointer<Void> signature =
      nativeMethodSignature(target.pointer, selectorPtr, typeEncodingsPtrPtr);
  if (signature.address == 0) {
    throw 'signature for [$target $selector] is NULL.';
  }

  Pointer<Pointer<Void>> pointers;
  if (args != null) {
    pointers = allocate<Pointer<Void>>(count: args.length);
    for (var i = 0; i < args.length; i++) {
      var arg = args[i];
      if (arg == null) {
        throw 'One of args list is null';
      }
      Pointer<Utf8> argTypePtr =
          nativeTypeEncoding(typeEncodingsPtrPtr.elementAt(i + 1).value);
      String typeEncodings = convertEncode(argTypePtr);
      storeValueToPointer(arg, pointers.elementAt(i), typeEncodings, auto);
    }
  } else if (selector.name.contains(':')) {
    //TODO: need check args count.
    throw 'Arg list not match!';
  }

  Pointer<Void> resultPtr =
      _msgSend(target.pointer, selectorPtr, signature, pointers, queue);

  Pointer<Utf8> resultTypePtr = nativeTypeEncoding(typeEncodingsPtrPtr.value);
  String typeEncodings = convertEncode(resultTypePtr);
  free(typeEncodingsPtrPtr);

  dynamic result = loadValueFromPointer(resultPtr, typeEncodings, auto);
  if (pointers != null) {
    free(pointers);
  }

  return result;
}
