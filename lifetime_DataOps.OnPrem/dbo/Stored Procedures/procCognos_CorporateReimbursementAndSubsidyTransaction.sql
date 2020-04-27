
CREATE PROC [dbo].[procCognos_CorporateReimbursementAndSubsidyTransaction] (
    @StartDate DATETIME,
    @EndDate DATETIME,
    @ReasonCodeIDList VARCHAR(1000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON


DECLARE @AdjEndDate DateTime
SET @AdjEndDate = DateAdd(day,1,@EndDate)

DECLARE @ReportRunDateTime VARCHAR(21) 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')

SELECT DISTINCT ReasonCode.ReasonCodeID as ReasonCodeID,
     ReasonCode.Description as TransactionReason
  INTO #ReasonCodes
  FROM vReasonCode ReasonCode
  JOIN fnParsePipeList(@ReasonCodeIDList) ReasonCodeIDList
    ON Convert(Varchar,ReasonCode.ReasonCodeID) = ReasonCodeIDList.Item

SELECT ReasonCodes.TransactionReason,
MMSTran.MemberID, 
MMSTran.ReceiptComment, 
MMSTran.PostDateTime, 
MMSTran.TranAmount, 
Member.JoinDate, 
MembershipBalance.EFTAmount,
@StartDate AS HeaderStartDate,
@EndDate AS HeaderEndDate,
@ReportRunDateTime AS ReportRunDateTime

 FROM vMMSTran MMSTran
 JOIN vMember Member
 ON MMSTran.MemberID = Member.MemberID
 JOIN vMembershipBalance MembershipBalance
 ON MembershipBalance.membershipid = Member.membershipid
  JOIN #ReasonCodes ReasonCodes
 ON MMSTran.ReasonCodeID = ReasonCodes.ReasonCodeID
 WHERE MMSTran.ReceiptComment is not null 
 AND MMSTran.PostDateTime >= @StartDate
 AND  MMSTran.PostDateTime < @AdjEndDate
 ------ORDER BY ReceiptComment,Memberid desc


 DROP TABLE #ReasonCodes



END
