

CREATE PROCEDURE dbo.mmsCreateHouseAccount
  @ClubID INT
AS

DECLARE @ClubName            VARCHAR(50)
DECLARE @MembershipID        INT
DECLARE @MemberID            INT
DECLARE @MembershipAddressID INT
DECLARE @MembershipPhoneID   INT
DECLARE @MembershipBalanceID INT
DECLARE @CurrentYear INT
DECLARE @DLDate DATETIME
DECLARE @CSDate DATETIME
DECLARE @DayOffset TINYINT
DECLARE @CreatedDateTime DATETIME
DECLARE @UTCCreatedDateTime DATETIME
DECLARE @CreatedDateTimeZone VARCHAR(4)

BEGIN

  SET XACT_ABORT ON

  BEGIN TRANSACTION

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  -- Get the Club Name
  --
  SELECT @ClubName = ClubName
    FROM vClub
   WHERE ClubID = @ClubID

  IF @ClubName IS NULL
  BEGIN
    ROLLBACK TRANSACTION
    RAISERROR('Could not find ClubName in procedure mmsCreateHouseAccount',2,127) WITH SETERROR
    RETURN -1
  END

  -- See if a House Account already exists for the club
  SELECT @MembershipID = MembershipID
    FROM vMembership
   WHERE MembershipTypeID = 64 -- House Accounts
     AND ClubID = @ClubID

  IF @MembershipID IS NOT NULL
  BEGIN
    ROLLBACK TRANSACTION
    RAISERROR('Procedure mmsCreateHouseAccount detected the house account already exists',2,127) WITH SETERROR
    RETURN -1
  END

  -- Get Next Membership Primary Key
  EXEC mmsPrimaryKeyGetNext 'Membership', @NextPrimaryKey = @MembershipID OUTPUT
  IF @MembershipID IS NULL
  BEGIN
    ROLLBACK TRANSACTION
    RAISERROR('mmsPrimaryKeyGetNext failed for Membership in procedure mmsCreateHouseAccount',2,127) WITH SETERROR
    RETURN -1
  END

  -- Calcualted the time zone info

  SET @CurrentYear = YEAR(GETDATE())

  SET @DLDate = 'APR 1 ' + CONVERT(VARCHAR,@CurrentYear) 
  IF DATEPART(dw,@DLDate) > 1
    BEGIN
      SET @DayOffset = 7 - DATEPART(dw,@DLDate)  + 1
      SET @DLDate = DATEADD(d,@DayOffset,@DLDate)
    END
   
  SET @CSDate = 'OCT 31 ' + CONVERT(VARCHAR,@CurrentYear) 
  SET @DayOffset = DATEPART(dw,@CSDate) - 1
  SET @CSDate = DATEADD(d,-@DayOffset,@CSDate)

  SET @CreatedDateTime = GETDATE()
  SET @UTCCreatedDateTime = CASE
                           WHEN @CreatedDateTime < @DLDate
                                OR  @CreatedDateTime >= @CSDate
                             THEN DATEADD(HOUR,6,@CreatedDateTime)
                           ELSE DATEADD(HOUR,5,@CreatedDateTime)
                         END

  SET @CreatedDateTimeZone = CASE
                            WHEN @CreatedDateTime < @DLDate
                                 OR  @CreatedDateTime >= @CSDate
                              THEN 'CST'
                            ELSE 'CDT'
                          END

  -- Create the Membership record
  INSERT INTO vMembership(MembershipID, ClubID, AdvisorEmployeeID,
         ActivationDate, ExpirationDate, TotalContractAmount,
         MandatoryCommentFlag, ValEFTOptionID, MembershipTypeID, ValMembershipStatusID,
         CreatedDateTime, UTCCreatedDateTime, CreatedDateTimeZone)
  VALUES (@MembershipID, @ClubID, -1,
          GETDATE(), NULL, 0,
          0, 2, 134, 4, @CreatedDateTime, @UTCCreatedDateTime, @CreatedDateTimeZone)



  -- Get Next Membershipbalance Primary Key
  EXEC mmsPrimaryKeyGetNext 'MembershipBalance', @NextPrimaryKey = @MembershipBalanceID OUTPUT
  IF @MembershipBalanceID IS NULL
  BEGIN
    ROLLBACK TRANSACTION
    RAISERROR('mmsPrimaryKeyGetNext failed for Membershipbalance in procedure mmsCreateHouseAccount',2,127) WITH SETERROR
    RETURN -1
  END
  -- Create the Membershipbalance record
  INSERT INTO vMembershipBalance(MembershipBalanceID,MembershipID,CurrentBalance,EFTAmount,StatementBalance,AssessedDateTime,StatementDateTime,PreviousStatementBalance,PreviousStatementDateTime,CommittedBalance)
  VALUES(@MembershipBalanceID,@MembershipID,0,0,0,NULL,NULL,0,NULL,0 )

  -- Get Next Member Primary Key
  EXEC mmsPrimaryKeyGetNext 'Member', @NextPrimaryKey = @MemberID OUTPUT
  IF @MemberID IS NULL
  BEGIN
    ROLLBACK TRANSACTION
    RAISERROR('mmsPrimaryKeyGetNext failed for Member in procedure mmsCreateHouseAccount',2,127) WITH SETERROR
    RETURN -1
  END

  -- Create the Member record
  INSERT INTO vMember(MemberID, MembershipID, FirstName, LastName,
         ActiveFlag, HasMessageFlag, JoinDate,
         ValMemberTypeID)
  VALUES (@MemberID, @MembershipID, @ClubName, 'House Account',
          1, 0, GETDATE(),
          1)

  -- Get Next MembershipAddress Primary Key
  EXEC mmsPrimaryKeyGetNext 'MembershipAddress', @NextPrimaryKey = @MembershipAddressID OUTPUT
  IF @MembershipAddressID IS NULL
  BEGIN
    ROLLBACK TRANSACTION
    RAISERROR('mmsPrimaryKeyGetNext failed for MembershipAddress in procedure mmsCreateHouseAccount',2,127) WITH SETERROR
    RETURN -1
  END

  -- Create the MembershipAddress record
  INSERT INTO vMembershipAddress(MembershipAddressID, MembershipID, AddressLine1, AddressLine2,
         City, ValStateID, ValAddressTypeID, Zip)
  SELECT @MembershipAddressID, @MembershipID, AddressLine1, AddressLine2,
         City, ValStateID, 1, Zip
    FROM vClubAddress
   WHERE ClubID = @ClubID

  -- Get Next MembershipPhone Primary Key
  EXEC mmsPrimaryKeyGetNext 'MembershipPhone', @NextPrimaryKey = @MembershipPhoneID OUTPUT
  IF @MembershipPhoneID IS NULL
  BEGIN
    ROLLBACK TRANSACTION
    RAISERROR('mmsPrimaryKeyGetNext failed for MembershipPhone in procedure mmsCreateHouseAccount',2,127) WITH SETERROR
    RETURN -1
  END

  -- Create the MembershipPhone record
  INSERT INTO vMembershipPhone(MembershipPhoneID, MembershipID, AreaCode, ValPhoneTypeID, Number)
  SELECT @MembershipPhoneID, @MembershipID, AreaCode, 2, Number
    FROM vClubPhone
   WHERE ClubID = @ClubID

  COMMIT TRANSACTION

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity 

END

