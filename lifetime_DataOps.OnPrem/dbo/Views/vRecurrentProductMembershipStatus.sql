﻿
CREATE VIEW dbo.vRecurrentProductMembershipStatus AS 
SELECT RecurrentProductMembershipStatusID,ValMembershipStatusID,ValRecurrentProductTypeID
FROM MMS.dbo.RecurrentProductMembershipStatus WITH(NoLock)

