﻿CREATE VIEW dbo.vMemberCardDesign AS 
SELECT MemberCardDesignID,Description,BackgroundImage,FlagImage,ActiveFlag,AllowNonMembershipFlag,ValMemberCardCodeID,SpecialText1,SpecialText2,VendorCardValue
FROM MMS.dbo.MemberCardDesign WITH(NOLOCK)
