
CREATE PROC [dbo].[procCognos_PromptMembershipType] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON


Select P.ProductID,
    P.Description AS MembershipType,
	VMTA.ValMembershipTypeAttributeID,
	VMTA.Description AS MembershipTypeAttributeDescription,
	CASE WHEN P.ProductID in(14267)
	     THEN 'Y'
		 ELSE 'N'
		 END TotalHealthMembershipType
From vProduct P
JOIN vMembershipType MT
On P.ProductID = MT.ProductID
JOIN vMembershipTypeAttribute MTA
 ON MT.MembershipTypeID = MTA.MembershipTypeID
JOIN vValMembershipTypeAttribute VMTA
 ON MTA.ValMembershipTypeAttributeID = VMTA.ValMembershipTypeAttributeID
Where ValProductStatusID <> 3   ----- Not obsolete
AND P.Description Not Like 'Future PlaceHolder%'


END
