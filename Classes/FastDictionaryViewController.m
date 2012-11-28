//
//  FastDictionaryViewController.m
//  FastDictionary v. 0.5-alpha
//
//  Created by Gianluca Bertani on 16/06/10.
//  Copyright Flying Dolphin Studio 2010. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without 
//  modification, are permitted provided that the following conditions 
//  are met:
//
//  * Redistributions of source code must retain the above copyright notice, 
//    this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, 
//    this list of conditions and the following disclaimer in the documentation 
//    and/or other materials provided with the distribution.
//  * Neither the name of Gianluca Bertani nor the names of its contributors 
//    may be used to endorse or promote products derived from this software 
//    without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
//  POSSIBILITY OF SUCH DAMAGE.
//

#import "FastDictionaryViewController.h"
#import "FDFastDictionary.h"


#pragma mark -
#pragma mark Extension of FastDictionaryViewController

@interface FastDictionaryViewController ()


#pragma mark -
#pragma mark Internals

- (void) test;
- (void) log:(NSString *)text;
- (void) enableRunTest;

@end


@implementation FastDictionaryViewController


#pragma mark -
#pragma mark Initialization

- (id) init {
	if ((self= [super init])) {
		
		// Nothing to do
	}
	
	return self;
}

- (void) dealloc {
	if (_testThread)
		[_testThread release];
	
    [super dealloc];
}


#pragma mark -
#pragma mark Methods of UIViewController

- (void) loadView {
	[super loadView];
	
	_testThread= nil;
	
	numOfKeys= nil;
	numOfIters= nil;
	useInlineAsm= nil;
	checkData= nil;
	
	_numOfKeys= 10000;
	_numOfIters= 1;

#if !TARGET_IPHONE_SIMULATOR

	_useInlineAsm= YES;
	_checkData= NO;

#else // TARGET_IPHONE_SIMULATOR

	_useInlineAsm= NO;
	_checkData= YES;

#endif // !TARGET_IPHONE_SIMULATOR
	
	numOfKeys= [[UISlider alloc] initWithFrame:CGRectMake(183.0, 20.0, 118.0, 23.0)];
	numOfKeys.value= (float) _numOfKeys;
	numOfKeys.minimumValue= (float) _numOfKeys;
	numOfKeys.maximumValue= (float) (10 * _numOfKeys);
	numOfKeys.continuous= YES;
	[numOfKeys addTarget:self action:@selector(numOfKeysChanged) forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:numOfKeys];
	
	numOfIters= [[UISlider alloc] initWithFrame:CGRectMake(183.0, 50.0, 118.0, 23.0)];
	numOfIters.value= (float) _numOfIters;
	numOfIters.minimumValue= (float) _numOfIters;
	numOfIters.maximumValue= (float) (10 * _numOfIters);
	numOfIters.continuous= YES;
	[numOfIters addTarget:self action:@selector(numOfItersChanged) forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:numOfIters];
	
	useInlineAsm= [[UISwitch alloc] initWithFrame:CGRectMake(205.0, 80.0, 94.0, 27.0)];
	useInlineAsm.on= _useInlineAsm;
	[useInlineAsm addTarget:self action:@selector(useInlineAsmChanged) forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:useInlineAsm];
	
	checkData= [[UISwitch alloc] initWithFrame:CGRectMake(205.0, 110.0, 94.0, 27.0)];
	checkData.on= _checkData;
	[checkData addTarget:self action:@selector(checkDataChanged) forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:checkData];

	testResults.font= [UIFont fontWithName:@"Helvetica" size:11.0];
}


#pragma mark -
#pragma mark UI events and actions

- (IBAction) numOfKeysChanged {
	_numOfKeys= numOfKeys.value;
	numOfKeysLabel.text= [NSString stringWithFormat:@"Num. of keys: %dk", (_numOfKeys / 1000)];
}

- (IBAction) numOfItersChanged {
	_numOfIters= numOfIters.value;
	numOfItersLabel.text= [NSString stringWithFormat:@"Num. of iters: %d", _numOfIters];
}

- (IBAction) useInlineAsmChanged {
	_useInlineAsm= useInlineAsm.on;
}

- (IBAction) checkDataChanged {
	_checkData= checkData.on;
}

- (IBAction) runTest {
	if (_testThread)
		[_testThread release];
	
	[runTest setTitle:@"Test running..." forState:UIControlStateNormal];
	runTest.enabled= NO;
	
	_testThread= [[NSThread alloc] initWithTarget:self selector:@selector(test) object:nil];
	[_testThread start];
}


#pragma mark -
#pragma mark Internals

- (void) test {
    NSAutoreleasePool *pool= [[NSAutoreleasePool alloc] init];

	int num_of_keys= _numOfKeys;
	int num_of_iters= _numOfIters;
	BOOL use_inline_asm= _useInlineAsm;
	BOOL check_data= _checkData;
	
	NSString *message0= [NSString stringWithFormat:@"Starting test with %d keys and %d iterations per key.", num_of_keys, num_of_iters];
	[self performSelectorOnMainThread:@selector(log:) withObject:message0 waitUntilDone:YES];
	
	NSString *message0b= [NSString stringWithFormat:@"Using %s algorithm.", ((use_inline_asm) ? "inline ASM": "plain C")];
	[self performSelectorOnMainThread:@selector(log:) withObject:message0b waitUntilDone:YES];
	
	NSString *message0c= ((check_data) ? @"Checking data correctness." : @"Not checking data correctness.");
	[self performSelectorOnMainThread:@selector(log:) withObject:message0c waitUntilDone:YES];
	
	[self performSelectorOnMainThread:@selector(log:) withObject:@"Preparing data structures..." waitUntilDone:YES];
	
	NSMutableDictionary *dict= nil;
	FDFastDictionary *fastDict= nil;
	@try {
		dict= [[NSMutableDictionary alloc] initWithCapacity:num_of_keys];
		fastDict= [[FDFastDictionary alloc] initWithCapacity:num_of_keys];

	} @catch (NSException *e0) {
		NSString *message0y= [NSString stringWithFormat:@"Exception with name: '%@' and reason: '%@' caught while allocating data structures.", e0.name, e0.reason];
		[self performSelectorOnMainThread:@selector(log:) withObject:message0y waitUntilDone:YES];
	}
	
	fastDict.useInlineAsm= use_inline_asm;
	
	NSMutableArray *keys= [[NSMutableArray alloc] initWithCapacity:num_of_keys];
	for (int i= 0; i < num_of_keys; i++) {
		NSUInteger key= 0;
		SecRandomCopyBytes(kSecRandomDefault, sizeof(int), (uint8_t *) &key);
		key= key & 0x7fffffff;
		
		[keys addObject:[NSNumber numberWithInt:key]];
	}
	
	[self performSelectorOnMainThread:@selector(log:) withObject:@"Test running..." waitUntilDone:YES];
	
	NSDate *begin2= [NSDate date];
	
	for (int i= 0; i < num_of_keys; i++) {
		NSNumber *key= (NSNumber *) [keys objectAtIndex:i];
		NSNumber *value= key;
		
		id value2= nil;
		for (int j= 0; j < num_of_iters; j++) {
			[dict setObject:value forKey:key];

			if (check_data)
				value2= [dict objectForKey:key];
			
			[dict removeObjectForKey:key];
		}
		
		if (check_data && (value != value2)) {
			NSString *message1= [NSString stringWithFormat:@"- Value: %@ != value2: %@ in NSMutableDictionary for i: %d and key: %@.", value, value2, i, key];
			[self performSelectorOnMainThread:@selector(log:) withObject:message1 waitUntilDone:YES];
		}
	}
	
	NSDate *end2= [NSDate date];
	NSTimeInterval elapsed2= [end2 timeIntervalSinceDate:begin2];
	
	NSString *message2= [NSString stringWithFormat:@"* Elapsed with NSMutableDictionary: %.02f secs.", elapsed2];
	[self performSelectorOnMainThread:@selector(log:) withObject:message2 waitUntilDone:YES];
	
	NSDate *begin1= [NSDate date];
	
	for (int i= 0; i < num_of_keys; i++) {
		NSNumber *value= (NSNumber *) [keys objectAtIndex:i];
		int key= [value intValue];
		
		@try {

/* Uncomment to add debugging infos (slows down the test)
			NSString *message1x= [NSString stringWithFormat:@"- Executing put for i: %d and key: %d with value: %@ (bucket: %d)", i, key, value, [fastDict bucketForKey:key]];
			[self performSelectorOnMainThread:@selector(log:) withObject:message1x waitUntilDone:YES];
 */

			id value2= nil, value3= nil;
			for (int j= 0; j < num_of_iters; j++) {
				[fastDict putKey:key withValue:value];
				
				if (check_data)
					value2= [fastDict getKey:key];

				value3= [fastDict removeKey:key];
			}
			
/* Uncomment to add debugging infos (slows down the test)
			NSString *message1z= [NSString stringWithFormat:@"- Dump of FDFastDictionary: %@", [fastDict dump]];
			[self performSelectorOnMainThread:@selector(log:) withObject:message1z waitUntilDone:YES];
 */

			if (check_data && (value != value2)) {
				NSString *message1b= [NSString stringWithFormat:@"- Value: %@ != value2: %@ in FDFastDictionary for i: %d and key: %d.", value, value2, i, key];
				[self performSelectorOnMainThread:@selector(log:) withObject:message1b waitUntilDone:YES];
			}

			if (check_data && (value != value3)) {
				NSString *message1b= [NSString stringWithFormat:@"- Value: %@ != value3: %@ in FDFastDictionary for i: %d and key: %d.", value, value3, i, key];
				[self performSelectorOnMainThread:@selector(log:) withObject:message1b waitUntilDone:YES];
			}

		} @catch (NSException *e) {

			NSString *message1y= [NSString stringWithFormat:@"Exception with name: '%@' and reason: '%@' caught while putting for i: %d and key %d.", e.name, e.reason, i, key];
			[self performSelectorOnMainThread:@selector(log:) withObject:message1y waitUntilDone:YES];
		}
	}
	
	NSDate *end1= [NSDate date];
	NSTimeInterval elapsed1= [end1 timeIntervalSinceDate:begin1];
	
	NSString *message1= [NSString stringWithFormat:@"* Elapsed with FDFastDictionary: %.02f secs.", elapsed1];
	[self performSelectorOnMainThread:@selector(log:) withObject:message1 waitUntilDone:YES];
	
	if (elapsed1 < elapsed2) {
		NSString *message3= [NSString stringWithFormat:@"FDFastDictionary outperforms NSMutableDictionary by a factor of: %.02fx.", elapsed2/elapsed1];
		[self performSelectorOnMainThread:@selector(log:) withObject:message3 waitUntilDone:YES];
		
	} else {
		NSString *message3= [NSString stringWithFormat:@"NSMutableDictionary outperforms FDFastDictionary by a factor of: %.02fx.", elapsed1/elapsed2];
		[self performSelectorOnMainThread:@selector(log:) withObject:message3 waitUntilDone:YES];
	}
	
	[keys release];
	[fastDict release];
	[dict release];
	
	[self performSelectorOnMainThread:@selector(log:) withObject:@"Test completed." waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(log:) withObject:@"\n" waitUntilDone:YES];
	
	[self performSelectorOnMainThread:@selector(enableRunTest) withObject:nil waitUntilDone:YES];
	
	[pool drain];
}

- (void) log:(NSString *)text {
	NSLog(@"%@", text);
	
	NSString *resultsText= [testResults.text stringByAppendingFormat:@"%@\n", text];
	if ([resultsText length] > 2000)
		resultsText= [resultsText substringFromIndex:[resultsText length] -2000];
	
	testResults.text= resultsText;
	
	NSRange range;
	range.location= [testResults.text length] -2;
	range.length= 1;
	[testResults scrollRangeToVisible:range];
}

- (void) enableRunTest {
	[runTest setTitle:@"Run test" forState:UIControlStateNormal];
	runTest.enabled= YES;
}


@end
