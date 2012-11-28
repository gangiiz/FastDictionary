//
//  FMFastDictionary.m
//  FastDictionary v. 0.5-alpha
//
//  Created by Gianluca Bertani on 16/06/09.
//  Copyright 2009 Flying Dolphin Studio. All rights reserved.
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

#import "FDFastDictionary.h"


#pragma mark -
#pragma mark Extension of FDFastDictionary

@interface FDFastDictionary ()


#pragma mark -
#pragma mark Internals

- (NSUInteger) bucketForKey:(NSUInteger)aKey;
- (void) nextFreeItem;


#pragma mark -
#pragma mark Eratosthenes' sieve

+ (NSUInteger) firstPrimeBiggerThan:(NSUInteger)aNumber;


@end


@implementation FDFastDictionary


#pragma mark -
#pragma mark Initialization

- (id) initWithCapacity:(NSUInteger)capacity {
	if (self = [super init]) {
		_useInlineAsm= YES;

		_numBuckets= [FDFastDictionary firstPrimeBiggerThan:capacity];
		long double coeff= 1.0 / ((long double) _numBuckets);
		
		// 32 bit fixed point representation of coefficient
		_coeff= 0;
		_shift= 32;
		int i= 0;
		BOOL firstOne= NO;
		do {
			coeff *= 2.0;

			if (coeff >= 1.0) {
				_coeff= _coeff | 0x1;
				coeff -= 1.0;
				firstOne= YES;
			
			} else {
				if (!firstOne)
					_shift++;
			}
			
			if (firstOne)
				i++;

			if (i < 32)
				_coeff= _coeff << 1;
			else
				break;
		
		} while (YES);
		
		_buckets= (FDItemRef *) malloc(sizeof(FDItemRef) * _numBuckets);
		if (!_buckets) 
			@throw [[[NSException alloc] initWithName:@"Not enough memory" reason:[NSString stringWithFormat:@"Not enough available memory for requested capacity of %d items", capacity] userInfo:nil] autorelease];
		
		for (int i= 0; i < _numBuckets; i++)
			_buckets[i]= NULL;
		
		_items= (FDItemRef) malloc(sizeof(FDItem) * _numBuckets);
		if (!_items) {
			free((void *) _buckets);

			@throw [[[NSException alloc] initWithName:@"Not enough memory" reason:[NSString stringWithFormat:@"Not enough available memory for requested capacity of %d items", capacity] userInfo:nil] autorelease];
		}

		for (int i= 0; i < _numBuckets; i++)
			_items[i].used= NO;

		_freeItem= -1;
		[self nextFreeItem];
	}
	
	return self;
}

- (void) dealloc {
	
	for (int i= 0; i < _numBuckets; i++) {
		if (_items[i].used)
			[_items[i].value release];
	}

	free((void *) _items);
	free((void *) _buckets);
	
	[super dealloc];
}


#pragma mark -
#pragma mark Put operation

- (void) putKey:(NSUInteger)aKey withValue:(id)aValue {
	[aValue retain];

	NSUInteger bucket= [self bucketForKey:aKey];
	if (bucket == 0xffffffff)
		@throw [[[NSException alloc] initWithName:@"Put: key out of domain" reason:[NSString stringWithFormat:@"Value %d is not admitted for keys", aKey] userInfo:nil] autorelease];
	
	if (_useInlineAsm) {
	
#if !TARGET_IPHONE_SIMULATOR
		
		FDItemRef freeItem= &_items[_freeItem];
		FDItemRef usedItem= freeItem;

		__asm__ volatile (
						  //
						  // qihm_put.s
						  // FastDictionary
						  //
						  // Created by Corrado Vaccari.
						  // All rights reserved.
						  //

						  "	ldr	r6, [%[pBuckets], %[bucketNum], LSL #2]	     \n\t"
						  
						  // Check if bucket is null
						  "	cmp	r6, #0					                     \n\t"
						  "	movne	r9, %[pBuckets]				             \n\t"
						  "	addne   r9, r9, %[bucketNum], LSL #2	         \n\t"
						  "	bne	4f			                                 \n\t"
						  "	mov	r6, %[pBuckets]					             \n\t"
						  "	add	r6, r6, %[bucketNum], LSL #2		         \n\t"
						  "	eor	r5, r5, r5				                     \n\t"
						  
						  // Item not found, init spare one and add to the list
						  "3:		                                         \n\t"
						  " mov r8, %[pFreeItem]                             \n\t"
						  " str %[key], [r8], #4                             \n\t"
						  " str %[value], [r8], #4                           \n\t"
						  " str r5, [r8]                                     \n\t"
						  "	str	%[pFreeItem], [r6]			                 \n\t"
						  "	b	5f					                         \n\t"
						  
						  // Scan list for sample key
						  "4:				                                 \n\t"
						  "	ldr	r8, [r6]				                     \n\t"
						  "	cmp	%[key], r8					                 \n\t"
						  
						  // Item found
						  "	streq	%[value], [r6, #4]		                 \n\t"
						  "	moveq	%[pFreeItem], r6				         \n\t"
						  "	beq	5f					                         \n\t"
						  
						  // If sample key < item key then item not found (list is ordered by key)
						  "	movls	r6, r9				                     \n\t"
						  "	ldrls	r5, [r6]			                     \n\t"
						  "	bls	3b	                                         \n\t"
						  
						  // Next item
						  "	mov	r9, r6					                     \n\t"
						  "	add	r9, r9, #8				                     \n\t"
						  "	ldr	r6, [r9]				                     \n\t"
						  "	cmp	r6, #0					                     \n\t"

						  // No more items, end of list
						  "	moveq	r6, r9				                     \n\t"
						  "	eoreq	r5, r5, r5			                     \n\t"
						  "	beq	3b	                                         \n\t"

						  // End of scan loop
						  "	b	4b			                                 \n\t"

						  // End
						  "5:						                         \n\t"
						  
						  : [pFreeItem] "+r" (usedItem)
						  : [pBuckets] "r" (_buckets), [bucketNum] "r" (bucket), [key] "r" (aKey), [value] "r" (aValue)
						  : "r5", "r6", "r8", "r9", "cc", "memory");

		if (usedItem == freeItem) {
			freeItem->used= YES;

			[self nextFreeItem];
		}

#else // TARGET_IPHONE_SIMULATOR

		@throw [[[NSException alloc] initWithName:@"Inline ASM not available" reason:[NSString stringWithFormat:@"Inline ASM not available on the simulator"] userInfo:nil] autorelease];

#endif // !TARGET_IPHONE_SIMULATOR
		
	} else {

		FDItemRef freeItem= &_items[_freeItem];	
		
		FDItemRef item= _buckets[bucket];
		if (!item) {

			// No item at selected bucket,
			// bucket is empty and must be created 
			// with spare item
			freeItem->key= aKey;
			freeItem->value= aValue;
			freeItem->used= YES;

			_buckets[bucket]= freeItem;
			
			[self nextFreeItem];
			return;

		} else {

			// Found item at selected bucket,
			// start scanning linked list
			do {
				if (item->key == aKey) {

					// Item has sample key,
					// replace value with argument
					item->value= aValue;
					return;
				
				} else {
					if (item->next) {

						// Next element in the linked list
						item= item->next;

					} else {

						// End of the linked list,
						// add new item using spare one
						freeItem->key= aKey;
						freeItem->value= aValue;
						freeItem->used= YES;

						_buckets[bucket]= freeItem;
						
						[self nextFreeItem];
						return;
					}
				}
				
			} while (YES);
		}
	}
}


#pragma mark -
#pragma mark Contains operation

- (BOOL) containsKey:(NSUInteger)aKey {
	return ([self getKey:aKey] != nil);
}


#pragma mark -
#pragma mark Get operation

- (id) getKey:(NSUInteger)aKey {
	
	NSUInteger bucket= [self bucketForKey:aKey];
	if (bucket == 0xffffffff)
		@throw [[[NSException alloc] initWithName:@"Get: key out of domain" reason:[NSString stringWithFormat:@"Value %d is not admitted for keys", aKey] userInfo:nil] autorelease];
	
	if (_useInlineAsm) {
	
#if !TARGET_IPHONE_SIMULATOR

		FDItemRef *bucketItem= &_buckets[bucket];
		NSUInteger key= aKey;
		id value= nil;
		
		__asm__ volatile (
						  //
						  // qihm_get.s
						  // FastDictionary
						  //
						  // Created by Corrado Vaccari.
						  // All rights reserved.
						  //

						  "	ldr	r6, [%[pBucket]]	                \n\t"
						  
						  // Check if bucket is null
						  "	cmp	r6, #0					            \n\t"
						  "	bne	4f			                        \n\t"
						  
						  // Item not found
						  "3:			                            \n\t"
						  "	eor	%[key], %[key], %[key]				\n\t"
						  " b   5f                                  \n\t"
						  
						  // Scan list for sample key
						  "4:				                        \n\t"
						  "	ldr	r5, [r6]				            \n\t"
						  "	cmp	%[key], r5					        \n\t"
						  
						  // Item found
						  "	moveq	%[key], r6				        \n\t"
						  "	ldreq	%[value], [%[key], #4]		    \n\t"
						  "	beq	5f				                    \n\t"
						  
						  // If sample key < item key then item not found (list is ordered by key)
						  "	bls	3b		                            \n\t"
						  
						  // Next item
						  "	ldr	r6, [r6, #8]			            \n\t"
						  "	cmp	r6, #0					            \n\t"
						  
						  // No more items, end of list
						  "	beq	3b		                            \n\t"
						  
						  // End of scan loop
						  "	b	4b		                            \n\t"	
						  
						  // End
						  "5:					                    \n\t"
						  
						  : [key] "+&r" (key), [value] "+&r" (value)
						  : [pBucket] "r" (bucketItem)
						  : "r5", "r6", "cc");
		
		if (key)
			return value;
		else
			return nil;
	
#else // TARGET_IPHONE_SIMULATOR 
	
		@throw [[[NSException alloc] initWithName:@"Inline ASM not available" reason:[NSString stringWithFormat:@"Inline ASM not available on the simulator"] userInfo:nil] autorelease];
		
#endif // !TARGET_IPHONE_SIMULATOR 
		
	} else {
		
		FDItemRef item= _buckets[bucket];
		if (!item) {

			// No item at selected bucket,
			// we have finished
			return nil;
		
		} else {

			// Found item at selected bucket,
			// start scanning linked list
			do {
				if (item->key == aKey) {

					// Item has sample key,
					// return its value
					return item->value;
					
				} else {
					if (item->next) {

						// Next element in the linked list
						item= item->next;
						
					} else {
						
						// End of the linked list,
						// sample key is not present
						return nil;
					}
				}
				
			} while (YES);
		}
	}
}


#pragma mark -
#pragma mark Remove operation

- (id) removeKey:(NSUInteger)aKey {

	NSUInteger bucket= [self bucketForKey:aKey];
	if (bucket == 0xffffffff)
		@throw [[[NSException alloc] initWithName:@"Remove: key out of domain" reason:[NSString stringWithFormat:@"Value %d is not admitted for keys", aKey] userInfo:nil] autorelease];

	if (_useInlineAsm) {

#if !TARGET_IPHONE_SIMULATOR 

		FDItemRef *bucketItem= &_buckets[bucket];
		FDItemRef removedItem= NULL;
		NSUInteger key= aKey;
		
		__asm__ volatile (
						  //
						  // qihm_del.s
						  // FastDictionary
						  //
						  // Created by Corrado Vaccari.
						  // All rights reserved.
						  //

						  "	ldr	r6, [%[pBucket]]	                \n\t"
						  "	mov	r8, r6					            \n\t"
						  
						  // Check if bucket is null
						  "	cmp	r6, #0								\n\t"
						  " bne	4f									\n\t"
						  
						  // Item not found
						  "3:										\n\t"
						  "	eor	%[key], %[key], %[key]				\n\t"
						  " b   6f                                  \n\t"
						  
						  // Scan list for sample key
						  "4:										\n\t"
						  " ldr	r5, [r6]							\n\t"
						  " cmp	%[key], r5							\n\t"
						  
						  // Item found
						  " moveq	%[key], r6						\n\t"
						  " beq	5f									\n\t"
						  
						  // If sample key < item key then item not found (list is ordered by key)
						  " bls	3b									\n\t"

						  // Next item
						  " mov	r8, r6								\n\t"
						  " ldr	r6, [r6, #8]						\n\t"
						  " cmp	r6, #0								\n\t"
						  
						  // No more items, end of list
						  " beq	3b									\n\t"
						  
						  // End of scan loop
						  " b	4b									\n\t"

						  // Remove item
						  "5:										\n\t"
						  " cmp	r6, r8								\n\t"
						  " moveq	r8, %[pBucket]					\n\t"
						  " ldr	r5, [r6, #8]						\n\t"
						  " str	r5, [r8]							\n\t"
						  
						  // End
						  "6:										\n\t"
						  " mov	%[item], %[key]						\n\t"
						  
						  : [key] "+&r" (key), [item] "+&r" (removedItem)
						  : [pBucket] "r" (bucketItem)
						  : "r5", "r6", "r8", "r9", "cc", "memory");
		
		if (removedItem) {
			removedItem->used= NO;
			return removedItem->value;

		} else
			return nil;

#else // TARGET_IPHONE_SIMULATOR 

		@throw [[[NSException alloc] initWithName:@"Inline ASM not available" reason:[NSString stringWithFormat:@"Inline ASM not available on the simulator"] userInfo:nil] autorelease];
		
#endif // !TARGET_IPHONE_SIMULATOR 
		
	} else {
	
		FDItemRef item= _buckets[bucket];
		if (!item) {

			// No item at selected bucket,
			// we have finished
			return nil;
			
		} else {

			// Found item at selected bucket,
			// start scanning linked list
			FDItemRef prev= NULL;
			do {
				if (item->key == aKey) {

					// Item has sample key
					id value= item->value;

					if (prev == NULL) {

						// We are on first item
						if (item->next) {

							// Add the bucket to next item
							_buckets[bucket]= item->next;

						} else {

							// Clear the bucket
							_buckets[bucket]= NULL;
						}
						
					} else {

						// We are not on first node,
						// unlink the item
						prev->next= item->next;
					}
						
					// Mark the item as spare
					// and return its value
					item->used= NO;
					return [value autorelease];
					
				} else {
					if (item->next) {

						// Next element in the linked list
						prev= item;
						item= item->next;
						
					} else {

						// End of the linked list,
						// sample key is not present
						return nil;
					}
				}
				
			} while (YES);
		}
	}
}


#pragma mark -
#pragma mark Internals

- (NSUInteger) bucketForKey:(NSUInteger)aKey {
	NSUInteger bucket= 0;
	
	if (_useInlineAsm) {
		
#if !TARGET_IPHONE_SIMULATOR

		__asm__ volatile (
						  //
						  // _calc_bucket.s
						  // FastDictionary
						  //
						  // Created by Corrado Vaccari.
						  // All rights reserved.
						  //

						  " mov r6, #0                                            \n\t"
						  " sub r6, r6, #1                                        \n\t"
						  " mov r5, r6, LSR #1                                    \n\t"

						  // Domain check for key
						  " cmp	%[key], r5                                        \n\t"
						  " movhi	%[bucketNum], r6                              \n\t"
						  " bhi	1f                                                \n\t"
						  
						  // 64 bit fixed point quotient
						  " umull	r5, %[bucketNum], %[key], %[coeff]            \n\t"

						  // 32 bit integer quotient
						  " sub	%[shift], %[shift], #32                           \n\t"
						  " mov	r5, %[bucketNum], LSR %[shift]                    \n\t"
						  " mul	%[bucketNum], %[numBuckets], r5                   \n\t"
						  
						  // 32 bit remainder
						  " sub	%[bucketNum], %[key], %[bucketNum]                \n\t"
						  " cmp	%[numBuckets], %[bucketNum]                       \n\t"

						  // Precision correction
						  " subls	%[bucketNum], %[bucketNum], %[numBuckets]     \n\t"
						  
						  // End
						  "1:                                                     \n\t"

						  : [bucketNum] "+r" (bucket)
						  : [key] "r" (aKey), [numBuckets] "r" (_numBuckets), [coeff] "r" (_coeff), [shift] "r" (_shift)
						  : "r5", "r6", "cc");

/* Uncomment to add debugging checks
		if ((aKey > 0x7fffffff) && (bucket != 0xffffffff))
			@throw [[[NSException alloc] initWithName:@"Error in bucket algorithm" reason:[NSString stringWithFormat:@"Should have returned: 0xffffffff for key: %d, instead it is: 0x%08x", aKey, bucket] userInfo:nil] autorelease];

		unsigned long long q= ((unsigned long long) aKey) * ((unsigned long long) _coeff);
		NSUInteger q2= (NSUInteger) (q >> _shift);
		NSUInteger r= aKey - (q2 * _numBuckets);
		if (r >= _numBuckets)
			r -= _numBuckets;
		
		if (bucket != r)
			@throw [[[NSException alloc] initWithName:@"Error in bucket algorithm" reason:[NSString stringWithFormat:@"Should have returned: %d for key: %d, instead it is: %d", r, aKey, bucket] userInfo:nil] autorelease];
		
		NSUInteger bucket2= aKey % _numBuckets;
		if (bucket != bucket2) 
			@throw [[[NSException alloc] initWithName:@"Error in bucket algorithm" reason:[NSString stringWithFormat:@"Bucket should be: %d for key: %d, instead it is: %d", bucket2, aKey, bucket2] userInfo:nil] autorelease];
*/		

#else // TARGET_IPHONE_SIMULATOR 

		@throw [[[NSException alloc] initWithName:@"Inline ASM not available" reason:[NSString stringWithFormat:@"Inline ASM not available on the simulator"] userInfo:nil] autorelease];

#endif // !TARGET_IPHONE_SIMULATOR 

	} else {
		
		// Domanin check for key
		if (aKey > 0x7fffffff)
			return 0xffffffff;
		
		// 64 bit fixed point quotient
		unsigned long long q= ((unsigned long long) aKey) * ((unsigned long long) _coeff);
		
		// 32 bit integer quotient
		NSUInteger q2= (NSUInteger) (q >> _shift);

		// 32 bit remainder
		NSUInteger r= aKey - (q2 * _numBuckets);
		
		// Precision correction
		if (r >= _numBuckets)
			r -= _numBuckets;
		
		bucket= r;
	}

/* Uncomment to add debugging checks
	NSUInteger bucket2= aKey % _numBuckets;
	if (bucket != bucket2) 
		@throw [[[NSException alloc] initWithName:@"Error in bucket" reason:[NSString stringWithFormat:@"Error in bucket: %d != %d -- key: %d", bucket, bucket2, aKey] userInfo:nil] autorelease];
*/
	
	return bucket;
}

- (void) nextFreeItem {
	_freeItem++;
	if (_freeItem == _numBuckets)
		_freeItem= 0;

	int startPos= _freeItem;
	while (_items[_freeItem].used) {
		_freeItem++;
		if (_freeItem == _numBuckets)
			_freeItem= 0;
		
		if (_freeItem == startPos)
			@throw [[[NSException alloc] initWithName:@"Capacity limit reached" reason:@"No more free items available" userInfo:nil] autorelease];
	}
}


#pragma mark -
#pragma mark Debugging

- (NSString *) dump {
	NSMutableString *dump= [[NSMutableString alloc] initWithCapacity:50000];
	
	[dump appendString:@"\n"];

	for (int i= 0; i < _numBuckets; i++) {
		FDItemRef item= _buckets[i];

		if (item) {
			[dump appendFormat:@"Bucket: %d - ", i];
		
			while (item) {
				[dump appendFormat:@"[used: %d, key: %d, value: %@]", item->used, item->key, item->value];
				
				if (item->next)
					[dump appendString:@" -> "];
				
				item= item->next;
			}
			
			[dump appendString:@"\n"];
		}
	}
	
	return [dump autorelease];
}


#pragma mark -
#pragma mark Eratosthenes' sieve

+ (NSUInteger) firstPrimeBiggerThan:(NSUInteger)aNumber {
	NSUInteger first25primes[25]= { 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97 };

	if (aNumber < 97) {
		NSUInteger *primes= first25primes;
		
		int pos= 0;
		do {
			if (primes[pos] > aNumber)
				return primes[pos];
			
			pos++;
		} while (YES);
		
	} else {
		NSUInteger *primes= (NSUInteger *) CFAllocatorAllocate(kCFAllocatorDefault, (aNumber / 3) * sizeof(NSUInteger), 0);
		for (int i= 0; i < 25; i++)
			primes[i]= first25primes[i];
		
		int pos= 25;
		NSUInteger next= 99;
		do {
			BOOL prime= YES;
			for (int i= 0; i < pos; i++) {
				if (next % primes[i] == 0) {
					prime= NO;
					break;
				}
			}
			
			if (prime) {
				primes[pos]= next;
				pos++;
				
				if (next > aNumber) {
					CFAllocatorDeallocate(kCFAllocatorDefault, (void *) primes);
					return next;
				}
			}
			
			next += 2;
		} while (YES);
	}
}


#pragma mark -
#pragma mark Properties

@synthesize useInlineAsm= _useInlineAsm;


@end
