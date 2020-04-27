CREATE TABLE [dbo].[tmpMemberReimbursementHistory] (
    [MemberReimbursementHistoryID] INT            NOT NULL,
    [MembershipID]                 INT            NULL,
    [MemberID]                     INT            NULL,
    [ReimbursementProgramID]       INT            NULL,
    [UsageFirstOfMonth]            DATETIME       NULL,
    [EnrollmentDate]               DATETIME       NULL,
    [MonthlyDues]                  NUMERIC (8, 4) NULL,
    [EstimatedReimbursementAmount] NUMERIC (8, 4) NULL,
    [ActualReimbursementAmount]    NUMERIC (8, 4) NULL,
    [ClubID]                       INT            NULL,
    [MMSTranID]                    INT            NULL,
    [ReimbursementErrorCodeID]     INT            NULL,
    [ReimbursementQualifiedFlag]   BIT            NULL,
    [QualifiedClubUtilization]     SMALLINT       NULL,
    [InsertedDateTime]             DATETIME       CONSTRAINT [DF_tmpMemberReimbursementHistory_InsertedDateTime] DEFAULT (getdate()) NULL,
    [UpdatedDateTime]              DATETIME       NULL
);

