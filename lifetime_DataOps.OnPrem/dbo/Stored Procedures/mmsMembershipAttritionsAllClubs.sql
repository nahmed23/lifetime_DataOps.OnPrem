﻿

--THIS PROCEDURE RETUNRS THE DETAILS OF MEMBERSHIP ATTRITIONS 
--IN THE CURRENT MONTH.

CREATE PROCEDURE mmsMembershipAttritionsAllClubs

AS
BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON
  EXEC mmsMembershipAttritions ''
END



