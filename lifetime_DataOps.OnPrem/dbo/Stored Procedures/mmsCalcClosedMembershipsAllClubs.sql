﻿
--THIS PROCEDURE RETUNRS THE DETAILS OF COMMISSION FOR MAs FOR MEMBERSHIPS SOLD 
--FOR MONTH TO DAY TILL YESTERDAY FOR ALL CLUBS.


CREATE PROCEDURE mmsCalcClosedMembershipsAllClubs
AS
BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON
  EXEC mmsCalcClosedMemberships ''
END


