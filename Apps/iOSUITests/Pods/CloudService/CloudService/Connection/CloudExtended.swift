
/*
******************************************************************
* COPYRIGHT (c) <<2020>> <<tanu inc  >>         *
*
 * All rights reserved                                           *
*
 * This software embodies materials and concepts which are       *
* confidential to <<Customer Name>> and is made available solely *
* pursuant to the terms of a written license agreement with      *
* <<tanu Product>>.                                            *
*
* Designed and Developed by tanu inc Industries, Inc.
.           *
*----------------------------------------------------------------*
* MODULE OR UNIT: CloudService                                *
*
* PROGRAMMER :  Tanuja Awasthi                                   *
* DATE       :  19/07/20                                         *
* VERSION    :  1.0                                              *
*
*----------------------------------------------------------------*
*
* MODULE SUMMARY : Public cloud connect class make deferent
   request by using this class                                   *
*
*
*
*
*----------------------------------------------------------------*
*
* TRACEABILITY RECORDS to SW requirements and detailed design :  *
* iOS 10 and onward
*
*
*----------------------------------------------------------------*
*
* MODIFICATION RECORDS                                           *
*
******************************************************************
*/

/// Type that acts as a generic extension point for all `CloudServiceExtended` types.
public struct CloudExtendedExtension<ExtendedType> {
    /// Stores the type or meta-type of any extended type.
    public private(set) var type: ExtendedType

    /// Create an instance from the provided value.
    ///
    /// - Parameter type: Instance being extended.
    public init(_ type: ExtendedType) {
        self.type = type
    }
}

/// Protocol describing the `af` extension points for CloudService extended types.
public protocol CloudExtended {
    /// Type being extended.
    associatedtype ExtendedType

    /// Static CloudService extension point.
    static var cloud: CloudExtendedExtension<ExtendedType>.Type { get set }
    /// Instance CloudService extension point.
    var  cloud: CloudExtendedExtension<ExtendedType> { get set }
}

public extension CloudExtended {
    /// Static CloudService extension point.
    static var cloud: CloudExtendedExtension<Self>.Type {
        get { CloudExtendedExtension<Self>.self }
        set {}
    }

    /// Instance CloudService extension point.
    var cloud: CloudExtendedExtension<Self> {
        get { CloudExtendedExtension(self) }
        set {}
    }
}
