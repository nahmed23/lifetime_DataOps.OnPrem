


CREATE VIEW dbo.vMemberTermination
	(Region
	,Club
	,TerminationReason
	,LastName
	,FirstName
	,MembershipID
	,AreaCode1
	,PhoneNumber1
	,AreaCode2
	,PhoneNumber2
	,CancelDate
	,ExpirationDate
	,MembershipType
	,MembershipStatus)
AS 
  SELECT AL6.Description
	,AL1.ClubName	
	,AL5.Description
	,AL3.LastName
	,AL3.FirstName
	,AL3.MemberID
	,AL4.AreaCode
	,AL4.Number
	,AL8.AreaCode
	,AL8.Number
	,AL2.CancellationRequestDate
	,AL2.ExpirationDate
	,AL10.Description
	,AL2.ValMembershipStatusID 
   FROM  MMS.dbo.Club 		AL1
	,MMS.dbo.Member 		AL3
	,MMS.dbo.ValRegion 		AL6
	,MMS.dbo.ValMemberType 	AL7
	,MMS.dbo.MembershipType 	AL9
	,MMS.dbo.Product 		AL10
	,dbo.vDelinquentMembers AL11
	,MMS.dbo.Membership 	AL2 
	LEFT OUTER JOIN MMS.dbo.MembershipPhone 	  AL4 ON (AL2.MembershipID		= AL4.MembershipID) 
	LEFT OUTER JOIN MMS.dbo.ValTerminationReason  AL5 ON (AL5.ValTerminationReasonID	= AL2.ValTerminationReasonID) 
	LEFT OUTER JOIN MMS.dbo.MembershipPhone 	  AL8 ON (AL2.MembershipID		= AL8.MembershipID) 
  WHERE (AL2.ClubID		= AL1.ClubID 
    AND  AL3.MembershipID	= AL2.MembershipID 
    AND  AL6.ValRegionID	= AL1.ValRegionID 
    AND  AL7.ValMemberTypeID	= AL3.ValMemberTypeID 
    AND  AL9.MembershipTypeID	= AL2.MembershipTypeID 
    AND  AL9.ProductID		= AL10.ProductID 
    AND  AL11.MembershipID	= AL2.MembershipID 
    AND  AL7.Description='Primary' 
    AND  AL4.ValPhoneTypeID=1 
    AND  AL8.ValPhoneTypeID=2) 


