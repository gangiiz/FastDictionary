
FastDictionary
==============

Introduction
------------

FastDictionary is an experimental implementation of an integer hash map
(i.e.: a hash map that uses integer as keys and objects as values) for
iOS, where the low level map management code is written both in
Objective-C and in ARM assembly.

The hash map algorithm and data structure, engineered by Gianluca
Bertani, are specifically optimized for integer keys, by using a bucket
array of a size that is always a prime number (Eratosthenes' sieve is
used during initialization to size it appropriately). On the other hand,
the ARM assembly code, engineered by Corrado Vaccari, has been carefully
handcrafted to make use of the execution pipeline and branch prediction.
The result is a hash map that is really fast.

Actual speed depends on the processor and the usage pattern, but using
the embedded test environment on an iPhone 3G, with 10k keys and 10
passes each key, you can typically obtain results like these:
- NSMutableDictionary comparison factor: 1x
- FDFastDictionary with C code: ~2.5x faster than NSMutableDictionary
- FDFastDictionary with assembly code: ~3.5x faster then
  NSMutableDictionary

Obviously, using integers as keys (specifically integers in the range 0
to 2^31-1, MSB must be left unused) is not for every application, but in
some cases they can fit very well. Moreover, a pair of macros have been
included with which you can easily transform a C string or an NSString
to a 32 bit integer by shifting first 4 chars accordingly. Consider the
added overhead, anyway. Use them in this way:

	STR_2_UINT("abcd") = 0x61626364
	NSSTR_2UINT(@"KEY") = 0x4B455900

FastDictionary has been tested, but you know: bugs can hide in every
corner of software development, so use it at your own risk. Of course,
we would be glad to have feedback from you, and in particular if you
find bugs or crashes.

What is contained here
----------------------

The source repository contains an XCode project, FastDictionary, that is
an iPhone test app with a simple GUI that lets you test the hash map
with a number of parameters.

Getting started
---------------

Use of the fast dictionary is pretty straightforward. When creating an
instance it's important to give it a good estimate of the expected
number of keys:

	FDFastDictionary *fastDict= fastDict= [[FDFastDictionary alloc]
		initWithCapacity:num_of_keys];

Initializing the dictionary may take a while: it will look for a prime
number close to your number of keys. Do it when you can waste a few seconds,
if your expected number of keys is large.

You can then switch on the use on inline assembly code with its property:

	fastDict.useInlineAsm= YES;

Finally, put, get or remove key/value pairs with its respective methods:

	// Add a key/value pair
	[fastDict putKey:key withValue:value];

	// Get value by key
	id value= [fastDict getKey:key];

	// Remove a value by key
	id value= [fastDict removeKey:key];

License
-------

The library is distributed under the New BSD License.

Version history
---------------

Version 0.5:
- First public alpha release.

Compatibility
-------------

Version 0.5 has been tested on iOS 4.2.1 running on an iPhone 3G,
and on iOS 4.3.5 running on an iPad. Please report any compatibility
issues that should come out.

