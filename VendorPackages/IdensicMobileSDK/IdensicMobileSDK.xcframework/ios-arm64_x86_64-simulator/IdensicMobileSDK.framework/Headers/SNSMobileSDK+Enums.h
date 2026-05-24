//
//  SNSMobileSDK+Enums.h
//  IdensicMobileSDK
//

#ifndef SNSMobileSDK_Enums_h
#define SNSMobileSDK_Enums_h

/**
 * Environment the SDK should operate on
 */
typedef NSString * SNSEnvironment NS_TYPED_EXTENSIBLE_ENUM;
/// Production environment
extern SNSEnvironment _Nonnull const SNSEnvironmentProduction;

/**
 * SDK Status
 */
typedef NS_CLOSED_ENUM(NSInteger, SNSMobileSDKStatus) {
    
    /// SDK is initialized and ready to be presented
    SNSMobileSDKStatus_Ready,
    
    /// SDK fails for some reasons (see `failReason` and `verboseStatus` for details)
    SNSMobileSDKStatus_Failed,
    
    /// No verification steps are passed yet
    SNSMobileSDKStatus_Initial,
    
    /// Some but not all of the verification steps have been passed over
    SNSMobileSDKStatus_Incomplete,
    
    /// Verification is pending
    SNSMobileSDKStatus_Pending,
    
    /// Applicant has been declined temporarily
    SNSMobileSDKStatus_TemporarilyDeclined,
    
    /// Applicant has been finally rejected
    SNSMobileSDKStatus_FinallyRejected,
    
    /// Applicant has been approved
    SNSMobileSDKStatus_Approved,
    
    /// Applicant action has been completed (see `actionResult` for details)
    SNSMobileSDKStatus_ActionCompleted,
    
} NS_SWIFT_NAME(SNSMobileSDK.Status);


/**
 * Fail reasons (see `verboseStatus` for details of the fail)
 */
typedef NS_ENUM(NSInteger, SNSFailReason) {
    
    /// Unknown or no fail
    SNSFailReason_Unknown,
    
    /// An attempt to setup with invalid parameters
    SNSFailReason_InvalidParameters,
    
    /// Unauthorized access detected (most likely `accessToken` is invalid or expired and had failed to be refreshed)
    SNSFailReason_Unauthorized,
    
    /// Initial loading from backend is failed
    SNSFailReason_InitialLoadingFailed,
    
    /// No applicant is found for the given parameters
    SNSFailReason_ApplicantNotFound,
    
    /// Applicant is found, but is misconfigured (most likely lacks of idDocs)
    SNSFailReason_ApplicantMisconfigured,
    
    /// A network error occured (the user will be presented with Network Oops screen)
    SNSFailReason_NetworkError,
    
    /// Some unexpected error occured (the user will be presented with Fatal Oops screen)
    SNSFailReason_UnexpectedError,
    
    /// An initialization error occured
    SNSFailReason_InitializationError,
};

/**
 * Reactions of `actionResultHandler`
 */
typedef NS_ENUM(NSInteger, SNSActionResultHandlerReaction) {
    
    /// Allows further processing to be continued
    SNSActionResultHandlerReaction_Continue = 0,
    
    /// Cancels further processing
    SNSActionResultHandlerReaction_Cancel = 1,
    
};

/**
 * Log levels
 */
typedef NS_ENUM(NSInteger, SNSLogLevel) {
    
    /// Logs nothing
    SNSLogLevel_Off = 0,
    
    /// Logs errors (default)
    SNSLogLevel_Error = 1,
    
    /// Logs warnings
    SNSLogLevel_Warning = 2,
    
    /// Logs debug info
    SNSLogLevel_Info = 3,
    
    /// Logs even more debug info
    SNSLogLevel_Debug = 4,
    
    /// Logs as much as possible
    SNSLogLevel_Trace = 5
};

#pragma mark -

typedef NSString * SNSVerificationStepKey NS_TYPED_EXTENSIBLE_ENUM;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyDefault;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyIdentity;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyIdentity2;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyIdentity3;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyIdentity4;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeySelfie;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeySelfie2;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyProofOfResidence;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyProofOfResidence2;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyApplicantData;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyEmailVerification;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyPhoneVerification;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyQuestionnaire;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyVideoIdent;
extern SNSVerificationStepKey _Nonnull const SNSVerificationStepKeyEkyc;

typedef NSString * SNSVerificationStepState NS_TYPED_EXTENSIBLE_ENUM;
extern SNSVerificationStepState _Nonnull const SNSVerificationStepStateNotSubmitted;
extern SNSVerificationStepState _Nonnull const SNSVerificationStepStateSubmitted;
extern SNSVerificationStepState _Nonnull const SNSVerificationStepStateReviewing;
extern SNSVerificationStepState _Nonnull const SNSVerificationStepStateApproved;
extern SNSVerificationStepState _Nonnull const SNSVerificationStepStateDeclined;

typedef NSString * SNSDocumentTypeKey NS_TYPED_EXTENSIBLE_ENUM;
extern SNSDocumentTypeKey _Nonnull const SNSDocumentTypeKeyDefault;
extern SNSDocumentTypeKey _Nonnull const SNSDocumentTypeKeyIdCard;
extern SNSDocumentTypeKey _Nonnull const SNSDocumentTypeKeyPassport;
extern SNSDocumentTypeKey _Nonnull const SNSDocumentTypeKeyDrivers;
extern SNSDocumentTypeKey _Nonnull const SNSDocumentTypeKeyResidencePermit;

typedef NSString * SNSSceneType NS_TYPED_EXTENSIBLE_ENUM;
extern SNSSceneType _Nonnull const SNSSceneTypeFacescan;
extern SNSSceneType _Nonnull const SNSSceneTypeVideoSelfie;
extern SNSSceneType _Nonnull const SNSSceneTypePhotoSelfie;
extern SNSSceneType _Nonnull const SNSSceneTypePortraitSelfie;
extern SNSSceneType _Nonnull const SNSSceneTypeScanFrontSide;
extern SNSSceneType _Nonnull const SNSSceneTypeScanBackSide;
extern SNSSceneType _Nonnull const SNSSceneTypeData;
extern SNSSceneType _Nonnull const SNSSceneTypeConfirmation;
extern SNSSceneType _Nonnull const SNSSceneTypeQuestionnaire;
extern SNSSceneType _Nonnull const SNSSceneTypeVideoIdent;
extern SNSSceneType _Nonnull const SNSSceneTypeGeolocation;
extern SNSSceneType _Nonnull const SNSSceneTypeEkyc;

typedef NSString * SNSInstructionsBlockType NS_TYPED_EXTENSIBLE_ENUM;
extern SNSInstructionsBlockType _Nonnull const SNSInstructionsBlockTypeSingle;
extern SNSInstructionsBlockType _Nonnull const SNSInstructionsBlockTypeDo;
extern SNSInstructionsBlockType _Nonnull const SNSInstructionsBlockTypeDont;

typedef NS_ENUM(NSInteger, SNSInstructionsPlacement) {
    SNSInstructionsPlacement_InstructionsScreen,
    SNSInstructionsPlacement_BottomSheet,
};

typedef NSString * SNSMRTDScanState NS_TYPED_EXTENSIBLE_ENUM;
extern SNSMRTDScanState _Nonnull const SNSMRTDScanStatePreparing;
extern SNSMRTDScanState _Nonnull const SNSMRTDScanStateScanning;
extern SNSMRTDScanState _Nonnull const SNSMRTDScanStateScanned;
extern SNSMRTDScanState _Nonnull const SNSMRTDScanStateScanFailed;

#endif /* SNSMobileSDK_Enums_h */
