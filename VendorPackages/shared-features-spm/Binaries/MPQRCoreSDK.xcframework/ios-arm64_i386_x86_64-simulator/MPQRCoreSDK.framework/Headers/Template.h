//
//  Header.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 22/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#ifndef Header_h
#define Header_h

#define CreateGetterSetter(TGetterName, TSetterName, TTagName) - (NSString* _Nullable) TGetterName{return [self getTagInfoValueFor:TTagName];} - (void) TSetterName:(id _Nullable) TGetterName{[self setTagInfoValue:TGetterName for:TTagName];}

#endif /* Header_h */
