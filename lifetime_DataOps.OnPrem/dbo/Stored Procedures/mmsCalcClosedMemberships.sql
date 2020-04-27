

--THIS PROCEDURE RETUNRS THE DETAILS OF COMMISSION FOR MAs FOR MEMBERSHIPS SOLD 
--FOR MONTH TO DAY TILL YESTERDAY FOR A GIVEN CLUB(S).
-- WILL TAKE LIST OF CLUBS(SEPERATED BY COMMA) AS INPUT.

CREATE  PROCEDURE mmsCalcClosedMemberships
  @ClubIDList VARCHAR(1000)
AS
BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON
    DECLARE @Yesterday DATETIME
    DECLARE @FirstOfMonth DATETIME
    DECLARE @ToDay DATETIME

    -- Parse the ClubIDs into a temp table
    CREATE TABLE #ClubID(ClubID INT)
    EXEC procParseClubIDs @ClubIDList

    SET @Yesterday = DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
    SET @FirstOfMonth = CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
    SET @ToDay = CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)

    SELECT C.ClubName,C.ClubID
    INTO #Club
    FROM  dbo.vClub C JOIN #ClubID CI ON CI.ClubID = C.ClubID


    SELECT MT.MembershipID, MT.PostDateTime, M.MemberID PrimaryMemberID,C.ClubID,
           C.ClubName, P.Description ProductDescription,P1.Description MembershipTypeDescription,
           MTFS.Description MembershipSizeDescription,M.FirstName PrimaryMemberFirstName,
           M.LastName PrimaryMemberLastName,E1.FirstName AdvisorFirstName,
           E1.LastName AdvisorLastName,TI.ItemAmount,P.ProductID, M.JoinDate, 
           CSC.CommissionCount, E.FirstName CommEmployeeFirstName,
           E.LastName CommEmployeeLastName,MS.CompanyID,TI.Quantity, @Yesterday ReportDate
    FROM dbo.vMMSTran MT JOIN dbo.vTranItem TI ON MT.MMSTranID=TI.MMSTranID
                          JOIN dbo.vProduct P ON TI.ProductID=P.ProductID
                          JOIN dbo.vMembership MS ON MS.MembershipID=MT.MembershipID
                          JOIN dbo.vMember M ON MS.MembershipID=M.MembershipID
                          JOIN dbo.vMembershipType MST ON MS.MembershipTypeID=MST.MembershipTypeID
                          JOIN dbo.vProduct P1 ON MST.ProductID=P1.ProductID
                          JOIN dbo.vValMembershipTypeFamilyStatus MTFS ON MTFS.ValMembershipTypeFamilyStatusID=MST.ValMembershipTypeFamilyStatusID
                          JOIN dbo.vEmployee E1 ON MS.AdvisorEmployeeID=E1.EmployeeID
                          JOIN #Club C ON MT.ClubID=C.ClubID
                          LEFT OUTER JOIN dbo.vCommissionSplitCalc CSC ON TI.TranItemID=CSC.TranItemID 
                          LEFT OUTER JOIN dbo.vSaleCommission SC ON TI.TranItemID=SC.TranItemID
                          LEFT OUTER JOIN dbo.vEmployee E ON SC.EmployeeID=E.EmployeeID 
    WHERE MT.PostDateTime>=@FirstOfMonth AND	
          MT.PostDateTime<@ToDay AND
          MT.TranVoidedID IS NULL AND
          (P.Productid IN (88,89,156,154,155,174,286,316,317) 
           OR P.Description LIKE 'Short Term%') AND
          M.ValMemberTypeID=1

     DROP TABLE #ClubID
     DROP TABLE #Club
END








