﻿CREATE VIEW dbo.vPOSEmployeeRolePaymentTypeAccessType AS 
SELECT POSEmployeeRolePaymentTypeAccessTypeID,ValPaymentTypeID,ValEmployeeRoleID,ValPOSPaymentTypeAccessTypeID
FROM MMS.dbo.POSEmployeeRolePaymentTypeAccessType WITH(NOLOCK)
