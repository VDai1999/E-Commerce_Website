/*=========================================================================================================================

	NAME:						Leasing Database (LeasingDB)

	Database Description:		A database for an e-commerce website where lessors can lease out items to earn money, and lessees can pay 
								a fee to borrow them

	Author:						Manh Nguyen
								Dai Dong


=========================================================================================================================*/


USE master;
GO

IF DB_ID('LeasingDB') IS NOT NULL  DROP DATABASE LeasingDB;
GO

CREATE DATABASE LeasingDB;
GO

USE [LeasingDB];
GO






----------------------------------------------------------------------------------------------------------------------------------------------------------------
--******************* CREATE TABLES
----------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Users Table
CREATE TABLE Users(
	userId					INT					PRIMARY KEY												IDENTITY			NOT NULL,
	userName				VARCHAR(100)		NOT NULL,
	fName					VARCHAR(100)		NOT NULL,
	lName					VARCHAR(100)		NOT NULL,
	email					VARCHAR(200)		NOT NULL,
	password				VARBINARY(64)		NOT NULL,
	dateOfBirth				DATE				NOT NULL,
	phone					VARCHAR(10)			NOT NULL,
	isDeleted				BIT					NOT NULl												DEFAULT(0)
)
GO



-- PriceTye Table
CREATE TABLE PriceTypes(
	priceTypeId				INT					PRIMARY KEY												IDENTITY	NOT NULL,
	priceTypeDescription	VARCHAR(50)
)
GO



-- LeasePosts Table
CREATE TABLE LeasePosts(
	leasePostId				INT					PRIMARY KEY												IDENTITY			NOT NULL,
	userId					INT					FOREIGN KEY REFERENCES Users(userId),
	priceTypeId				INT					FOREIGN KEY REFERENCES PriceTypes(priceTypeId),
	description				VARCHAR(MAX)		NULL,
	condition				VARCHAR(50)			NOT NULL,
	itemAmount				INT					NOT NULL												DEFAULT(1),
	leaseStartDate			DATETIME			NOT NULL												DEFAULT(GETDATE()),
	leaseEndDate			DATETIME			NOT NULL,
	price					FLOAT				NOT NULl,
	dateCreated				DATETIME			NOT NULL												DEFAULT(GETDATE()),
	isDeleted				BIT					NOT NULL												DEFAULT(0)
)
GO



-- ItemsURL Table
CREATE TABLE ItemURLs(
	urlId					INT					PRIMARY KEY												IDENTITY			NOT NULL,
	leasePostId				INT					FOREIGN KEY REFERENCES LeasePosts(leasePostId),
	pictureURL				VARCHAR(1000)		NOT NULL
)
GO



-- Tags Table
CREATE TABLE Tags (
	tagId					INT					PRIMARY KEY												IDENTITY			NOT NULL,
	leasePostId				INT					FOREIGN KEY REFERENCES LeasePosts(leasePostId),
	tagName					VARCHAR(1000)		NOT NULL,
	tagDescription			VARCHAR(MAX)		NULL
)
GO




-- UserTags Table
CREATE TABLE UserTags(
	tagId					INT					FOREIGN KEY (tagId) REFERENCES Tags(tagId),
	userId					INT					FOREIGN KEY (userId) REFERENCES Users(userId),
	PRIMARY KEY (tagId, userId)
)
GO

-- Address Table
CREATE TABLE [Address](
	addressId				INT					PRIMARY KEY												IDENTITY			NOT NULL,
	userId					INT					FOREIGN KEY (userId) REFERENCES Users(userId),
	address1				VARCHAR(MAX)		NOT NULL,
	address2				VARCHAR(MAX),
	city					VARCHAR(1000)		NOT NULL,
	[state]					VARCHAR(1000)		NOT NULL,
	postalCode				INT					NOT NULL,
	country					VARCHAR(100)		NOT NULL,
	isDeleted				BIT					NOT NULL												DEFAULT(0)
)
GO

-- LeasePostReply Table
CREATE TABLE LeasePostReply (
	leasePostReplyId		INT					PRIMARY KEY												IDENTITY			NOT NULL,
	userId					INT					FOREIGN KEY (userId) REFERENCES Users(userId),			
	addressId				INT					FOREIGN KEY (addressId) REFERENCES [Address](addressId),
	leasePostId				INT					FOREIGN KEY (leasePostId) REFERENCES LeasePosts(leasePostId),
	[message]				TEXT,
	borrowStartDate			DATE				NOT NULL,
	borrowEndDate			DATE				NOT NULL,
	amount					INT					NOT NULL,
	[status]				VARCHAR(1)			NOT NULL,
	isDeleted				BIT					NOT NULL		DEFAULT(0)
)
GO

-- Errors Table
CREATE TABLE [dbo].[errors](
	[errorId] 				INT					PRIMARY KEY												IDENTITY(1,1)		NOT NULL												 ,
	[ERROR_NUMBER] 			INT					NOT NULL,
	[ERROR_SEVERITY] 		INT					NOT NULL,
	[ERROR_STATE] 			INT					NOT NULL,
	[ERROR_PROCEDURE] 		VARCHAR(50)			NOT NULL,
	[ERROR_LINE] 			INT					NOT NULL,
	[ERROR_MESSAGE] 		VARCHAR(500)		NOT NULL,
	[errorDate] 			DATETIME			NOT NULL												DEFAULT(getdate()),
	[resolvedOn]			DATETIME			NULL,
	[comments]				VARCHAR(8000)		NOT NULL												DEFAULT(''),
	[userName]				VARCHAR(100)		NOT NULL												DEFAULT(''),
	[params]				VARCHAR(MAX)		NOT NULL												DEFAULT('')
)
GO

----------------------------------------------------------------------------------------------------------------------------------------------------------------
--******************* CREATE VIEWS
----------------------------------------------------------------------------------------------------------------------------------------------------------------

-- vwUsers view
CREATE VIEW vwUsers AS 
	SELECT * 
	FROM Users 
	WHERE isDeleted = 0;
GO

-- vwLeasePosts view
CREATE VIEW vwLeasePosts AS 
	SELECT * 
	FROM LeasePosts 
	WHERE isDeleted = 0;
GO

-- vwAddress view
CREATE VIEW vwAddress AS
	SELECT * FROM Address 
	WHERE isDeleted = 0;
GO

-- vwLeasePostReply view
CREATE VIEW vwLeasePostReply AS 
	SELECT * 
	FROM LeasePostReply 
	WHERE isDeleted = 0;
GO

-- vwPendingLeasePostReply view
CREATE VIEW vwPendingLeasePostReply AS 
	SELECT * 
	FROM vwLeasePostReply
	WHERE [status] = 'p';
GO

-- vwCompletedLeasePostReply view
CREATE VIEW vwCompletedLeasePostReply AS 
	SELECT * 
	FROM vwLeasePostReply 
	WHERE [status] = 'c';
GO


---------------------------------------------------------------------------------------------------------------------------
----******************* CREATE FUNCTIONS
---------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION fnEncrypt (@str AS NVARCHAR(4000)) RETURNS VARBINARY(64) AS 
BEGIN
	RETURN HASHBYTES('SHA2_512', @str)
END
GO

-- validate phone number
CREATE FUNCTION fnValidatePhoneNumber (@phone AS VARCHAR(10)) RETURNS BIT AS
BEGIN
	RETURN IIF (EXISTS(SELECT NULL FROM vwUsers WHERE phone=@phone), 0, 1)
END 
GO

--validate username
CREATE FUNCTION fnValidateUsername (@username AS VARCHAR(100)) RETURNS BIT AS
BEGIN
	RETURN IIF (EXISTS(SELECT NULL FROM vwUsers WHERE username=@username), 0, 1)
END 
GO

-- validate email
CREATE FUNCTION fnValidateEmail (@email AS VARCHAR(200)) RETURNS BIT AS
BEGIN
	RETURN IIF (EXISTS(SELECT NULL FROM vwUsers WHERE email=@email), 0, 1)
END 
GO

-- login
CREATE FUNCTION fnLogin(@username AS VARCHAR(100), @password AS NVARCHAR(4000)) RETURNS BIT AS
BEGIN
	RETURN IIF (EXISTS(SELECT NULL FROM vwUsers WHERE username=@username AND password = dbo.fnEncrypt(@password)), 1, 0)
END 
GO






----------------------------------------------------------------------------------------------------------------------------------------------------------------
--******************* CREATE STORED PROCEDURES
----------------------------------------------------------------------------------------------------------------------------------------------------------------

/*=========================================================================================================================
	Name:				spSAVE_Error

	Description:		Saves current error
=========================================================================================================================*/
CREATE PROCEDURE spSAVE_Error
	@params varchar(MAX) = ''
AS
BEGIN
     SET NOCOUNT ON;
     BEGIN TRY
    	INSERT INTO errors (ERROR_NUMBER,   ERROR_SEVERITY,   ERROR_STATE,   ERROR_PROCEDURE,   ERROR_LINE,   ERROR_MESSAGE, userName, params)
		SELECT				ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE(), SUSER_NAME(), @params;
     END TRY BEGIN CATCH END CATCH
END
GO



/*=========================================================================================================================
	Name:				spAddUpdateDelete_User

	Description:		Add/update/delete users
=========================================================================================================================*/
CREATE PROCEDURE spAddUpdateDelete_User
	@userId			INT,
	@userName		VARCHAR(100),
	@fName			VARCHAR(100),
	@lName			VARCHAR(100),
	@email			VARCHAR(200),
	@password		VARCHAR(4000),
	@phone			VARCHAR(10),
	@dateOfBirth	DATE,
	@isDeleted		BIT = 0
AS BEGIN
	BEGIN TRAN
		BEGIN TRY
			IF(@userId = 0) BEGIN																										-- ADD
				IF dbo.fnValidateEmail(@email)=1 AND dbo.fnValidatePhoneNumber(@phone)=1 AND dbo.fnValidateUsername(@username)=1 BEGIN

					INSERT INTO Users(userName, fName, lName, email, password, phone, dateOfBirth)
					VALUES (@userName, @fName, @lName, @email, dbo.fnEncrypt(@password), @phone, @dateOfBirth)

					SELECT		@@IDENTITY AS userId,
								[success] = CAST(1 AS BIT),
								[message] = 'User added'
				END ELSE BEGIN
					SELECT	-1 AS userId,
							[message] = 'User cannot be added'
				END

			END ELSE IF(@isDeleted = 1) BEGIN																							-- DELETE
				IF NOT EXISTS (SELECT NULL FROM Users WHERE userId = @userId) BEGIN					
					SELECT		[message] = 'There is no such user',
								[success] = CAST(0 AS BIT)
				END ELSE IF	EXISTS (SELECT TOP(1) NULL FROM UserTags WHERE userId = @userId) OR
							EXISTS (SELECT TOP(1) NULL FROM LeasePosts WHERE userId = @userId) OR
							EXISTS (SELECT TOP(1) NULL FROM Address WHERE userId = @userId) OR
							EXISTS (SELECT TOP(1) NULL FROM LeasePostReply WHERE userId = @userId) BEGIN	-- SOFT DELETE
					
					UPDATE	users SET isDeleted = 1 WHERE userId = @userId							
					SELECT	[message] = 'Temporarily Deleted',
							[success] = CAST(1 AS BIT)
				END ELSE BEGIN																											-- HARD DELETE

					DELETE FROM LeasePostReply	WHERE		userId IN (SELECT userId FROM Users WHERE userId = @userId)
														OR  leasePostId IN (SELECT leasePostId FROM LeasePosts WHERE userId = @userId)
														OR  addressId IN (SELECT addressId FROM Address WHERE userId = @userId)
					DELETE FROM Address			WHERE		userId IN (SELECT userId FROM Users WHERE userId = @userId)
					DELETE FROM LeasePosts		WHERE		userId IN (SELECT userId FROM Users WHERE userId = @userId)
					DELETE FROM UserTags		WHERE		userId IN (SELECT userId FROM Users WHERE userId = @userId)

					DELETE FROM Users WHERE userId = @userId
					SELECT	[message] = 'Deleted',
							[success] = CAST(1 AS BIT)
				END

			END ELSE BEGIN																												-- UPDATE 
				IF NOT EXISTS(SELECT NULL FROM vwUsers WHERE userId = @userId) BEGIN
				--AND ((email = @email) OR (userName = @userName))
					SELECT		[message] = 'There is no such user',
								[success] = CAST(0 AS BIT)
				END ELSE BEGIN
					UPDATE Users 
					SET email = @email,
						userName = @userName,
						fName = @fName,
						lName = @lName,
						phone = @phone,
						dateOfBirth = @dateOfBirth
					WHERE userId = @userId
					SELECT		[message] = 'Updated',
								[success] = CAST(1 AS BIT)
				END
			END
		END TRY BEGIN CATCH
			IF(@@TRANCOUNT > 0) ROLLBACK TRAN
			DECLARE @errorParams varchar(max) = CONCAT(
														   '@userId = ', @userId
														,', @userName = ', @userName
														,', @email = ', @email		
														,', @password = ', @password
														,', @phhone = ', @phone
														,', @fName = ', @fName	
														,', @lName = ', @lName			
														,', @dateOfBirth = ', @dateOfBirth	
														,', @isDeleted = ', @isDeleted
													)
			EXEC spSAVE_Error @params = @errorParams
		END CATCH
	IF(@@TRANCOUNT > 0) COMMIT TRAN
END
GO


/*=========================================================================================================================
	Name:				spAddUpdateDelete_Address

	Description:		Add/update/delete a users' address
=========================================================================================================================*/
CREATE PROCEDURE spAddUpdateDelete_Address
	@addressId		INT,
	@userId			INT,
	@address1		VARCHAR(MAX),
	@address2		VARCHAR(MAX),
	@city			VARCHAR(1000),
	@state			VARCHAR(1000),
	@postalCode		INT,
	@country		VARCHAR(100),
	@isDeleted	    BIT = 0
AS BEGIN
	BEGIN TRAN
		BEGIN TRY

			IF	EXISTS(SELECT NULL FROM Users WHERE (userId = @userId)) BEGIN

				IF(@addressId = 0) BEGIN																						-- ADD
					INSERT INTO Address (userId, address1, address2, city, state, postalCode, country)
					VALUES (@userId, @address1, @address2, @city, @state, @postalCode, @country)
					SELECT	@@IDENTITY AS workoutId,
							[message] = 'Address added',
							[success] = CAST(1 AS BIT)
				END ELSE IF(@isDeleted = 1) BEGIN																				-- DELETE 
					IF NOT EXISTS (SELECT NULL FROM Address WHERE addressId=@addressId) BEGIN					
						SELECT		[message] = 'There is no such address',
									[success] = CAST(0 AS BIT)
					END ELSE IF EXISTS (SELECT TOP(1) NULL FROM LeasePostReply WHERE addressId=@addressId) BEGIN				-- SOFT DELETE
						UPDATE	Address SET isDeleted = 1 WHERE addressId = @addressId							
						SELECT	[message] = 'Temporarily Deleted',
								[success] = CAST(1 AS BIT)

					END ELSE BEGIN																								-- HARD DELETE
						DELETE FROM LeasePostReply WHERE addressId=@addressId
						DELETE FROM Address WHERE addressId=@addressId
						SELECT	[message] = 'Deleted',
								[success] = CAST(1 AS BIT)
					END

				END ELSE BEGIN																									-- UPDATE		
					IF EXISTS (SELECT NULL FROM vwAddress WHERE (addressId = @addressId)) BEGIN
						UPDATE Address
						SET		userId = @userId, 
								address1 = @addressId, 
								address2 = @address2, 
								city = @city, 
								state = @state, 
								postalCode = @postalCode, 
								country = @country
						WHERE (userId = @userId) AND (addressId = @addressId)
						SELECT	@addressId AS AdrressId,
								[message] = 'Address updated',
								[success] = CAST(1 AS BIT)
					END ELSE BEGIN
						SELECT	@addressId AS AdrressId,
								[message] = 'There is no such address',
								[success] = CAST(0 AS BIT)
					END
				END

			END ELSE BEGIN							
				SELECT			[message] = 'Failed',
								[success] = CAST(0 AS BIT)
			END
	
		END TRY BEGIN CATCH
			IF(@@TRANCOUNT > 0) ROLLBACK TRAN
			DECLARE @errorParams varchar(max) = CONCAT(  '  @addressId = ', @addressId
														,', @userId = ', @userId
														,', @address1 = ', @address1
														,', @address2 = ', @address2		
														,', @city = ', @city
														,', @state = ', @state
														,', @postalCode = ', @postalCode	
														,', @country = ', @country			
												)
	
			EXEC spSAVE_Error @params = @errorParams	

		END CATCH 
	IF(@@TRANCOUNT > 0) COMMIT TRAN

END
GO	



/*=========================================================================================================================
	Name:				spAddUpdateDeleteLeasePostReply

	Description:		Add/update/delete lease post reply
=========================================================================================================================*/
CREATE PROCEDURE spAddUpdateDelete_LeasePostReply
	@leasePostReplyId			INT,
	@userId						INT,
	@addressId					INT,
	@leasePostId				INT,
	@message					TEXT,
	@borrowStartDate			DATE,
	@borrowEndDate				DATE,
	@amount						INT,
	@status						VARCHAR(1),
	@isDeleted					BIT = 0
AS BEGIN
	BEGIN TRAN
		BEGIN TRY
			IF(@leasePostReplyId = 0) BEGIN																									-- ADD
				INSERT INTO LeasePostReply(userId, addressId, leasePostId, message, borrowStartDate, borrowEndDate, amount, status)
				VALUES (@userId, @addressId, @leasePostId, @message, @borrowStartDate, @borrowEndDate, @amount, @status)

				SELECT		@@IDENTITY AS leasePostReplyId,
							[success] = CAST(1 AS BIT),
							[message] = 'Reply added'

			END ELSE IF(@isDeleted = 1) BEGIN																								-- DELETE
				IF NOT EXISTS (SELECT NULL FROM LeasePostReply WHERE leasePostReplyId = @leasePostReplyId) BEGIN					
					SELECT		[message] = 'There is no such reply',
								[success] = CAST(0 AS BIT)
				END ELSE BEGIN	--  DELETE
					DELETE FROM LeasePostReply WHERE leasePostReplyId = @leasePostReplyId

					SELECT	0 AS leasePostReplyId,
							[success] = CAST(1 AS BIT),
							[message] = 'Reply deleted'		
				END

			END ELSE BEGIN																													-- UPDATE 
				IF NOT EXISTS(SELECT NULL FROM vwLeasePostReply WHERE (leasePostReplyId = @leasePostReplyId)) BEGIN
					SELECT		[message] = 'There is no such reply',
								[success] = CAST(0 AS BIT)
				END ELSE BEGIN
					UPDATE	LeasePostReply 
					SET		userId = @userId, 
							addressId = @addressId, 
							leasePostId = @leasePostId, 
							message = @message, 
							borrowStartDate = @borrowStartDate, 
							borrowEndDate = @borrowEndDate, 
							amount = @amount, 
							status = @status
					WHERE leasePostReplyId = @leasePostReplyId
					SELECT		[message] = 'Updated',
								[success] = CAST(1 AS BIT)
				END
			END
		END TRY BEGIN CATCH
			IF(@@TRANCOUNT > 0) ROLLBACK TRAN
			DECLARE @errorParams varchar(max) = CONCAT(	   '@leasePostReplyId = ', @leasePostReplyId
														,', @userId = ', @userId
														,', @addressId = ', @addressId
														,', @leasePostId	 = ', @leasePostId	
														,', @message = ', @message		
														,', @borrowStartDate = ', @borrowStartDate
														,', @borrowEndDate = ', @borrowEndDate
														,', @amount = ', @amount	
														,', @status = ', @status		
														,', @isDeleted = ', @isDeleted
													)
			EXEC spSAVE_Error @params = @errorParams
		END CATCH
	IF(@@TRANCOUNT > 0) COMMIT TRAN
END
GO



	
/*=========================================================================================================================
	Name:				spAddUpdateDeleteLeasePost

	Description:		Add/update/delete lease post
=========================================================================================================================*/
CREATE PROCEDURE spAddUpdateDelete_LeasePost
	@leasePostId				INT,
	@userId						INT,
	@priceTypeId				INT,
	@description				VARCHAR(MAX),
	@condition					VARCHAR(50),
	@itemAmount					INT,
	@leaseStartDate				DATETIME,
	@leaseEndDate				DATETIME,
	@price						FLOAT,
	@dateCreated				DATETIME,
	@isDeleted					BIT = 0
AS BEGIN
	BEGIN TRAN
		BEGIN TRY
			IF(@leasePostId = 0) BEGIN																												-- ADD
				INSERT INTO LeasePosts(userId, priceTypeId, description, condition, itemAmount, leaseStartDate, leaseEndDate, price, dateCreated)
				VALUES (@userId, @priceTypeId, @description, @condition, @itemAmount, @leaseStartDate, @leaseEndDate, @price, @dateCreated)

				SELECT		@@IDENTITY AS leasePostId,
							[success] = CAST(1 AS BIT),
							[message] = 'Post added'

			END ELSE IF(@isDeleted = 1) BEGIN																										-- DELETE

				IF NOT EXISTS (SELECT NULL FROM LeasePosts WHERE leasePostId = @leasePostId) BEGIN					
					SELECT		[message] = 'There is no such post',
								[success] = CAST(0 AS BIT)

				END ELSE IF	EXISTS (SELECT TOP(1) NULL FROM LeasePostReply WHERE leasePostId = @leasePostId) BEGIN									-- SOFT DELETE
					
					UPDATE LeasePosts SET isDeleted = 1 WHERE leasePostId = @leasePostId						
					SELECT	[message] = 'Temporarily Deleted',
							[success] = CAST(1 AS BIT)

				END ELSE BEGIN																														-- HARD  DELETE
					DELETE FROM LeasePostReply WHERE leasePostId = @leasePostId
					DELETE FROM LeasePosts WHERE leasePostId = @leasePostId

					SELECT	0 AS leasePostId,
							[success] = CAST(1 AS BIT),
							[message] = 'Post deleted'		
				END

			END ELSE BEGIN																															-- UPDATE 
				IF NOT EXISTS(SELECT NULL FROM vwLeasePosts WHERE (leasePostId = @leasePostId)) BEGIN
					SELECT		[message] = 'There is no such post',
								[success] = CAST(0 AS BIT)
				END ELSE BEGIN
					UPDATE	LeasePosts 
					SET		userId = @userId, 
							priceTypeId = @priceTypeId, 
							description = @description, 
							condition = @condition, 
							itemAmount = @itemAmount, 
							leaseStartDate = @leaseStartDate, 
							leaseEndDate = @leaseEndDate, 
							price = @price,
							dateCreated = @dateCreated
					WHERE leasePostId = @leasePostId
					SELECT		[message] = 'Updated',
								[success] = CAST(1 AS BIT)
				END
			END
		END TRY BEGIN CATCH
			IF(@@TRANCOUNT > 0) ROLLBACK TRAN
			DECLARE @errorParams varchar(max) = CONCAT(	   '@leasePostId = ', @leasePostId
														,', @userId = ', @userId
														,', @priceTypeId = ', @priceTypeId
														,', @description	 = ', @description	
														,', @condition = ', @condition		
														,', @itemAmount = ', @itemAmount
														,', @leaseStartDate = ', @leaseStartDate
														,', @leaseEndDate = ', @leaseEndDate	
														,', @price = ', @price		
														,', @dateCreated = ', @dateCreated
														,', @isDeleted = ', @isDeleted
													)
			EXEC spSAVE_Error @params = @errorParams
		END CATCH
	IF(@@TRANCOUNT > 0) COMMIT TRAN
END
GO




/*=========================================================================================================================
	Name:				spAddUpdate_Tag

	Description:		Add/update Tag
=========================================================================================================================*/
CREATE PROCEDURE spAddUpdate_Tag
	@tagId						INT,
	@leasePostId				INT,
	@tagName					VARCHAR(1000),
	@tagDescription				VARCHAR(MAX)
AS BEGIN
	BEGIN TRAN
		BEGIN TRY
			IF(@tagId = 0) BEGIN																											-- ADD
				INSERT INTO Tags(leasePostId, tagName, tagDescription)
				VALUES (@leasePostId, @tagName, @tagDescription)

				SELECT		@@IDENTITY AS tagId,
							[success] = CAST(1 AS BIT),
							[message] = 'Tag added'

			END ELSE BEGIN																													-- UPDATE 
				IF NOT EXISTS(SELECT NULL FROM Tags WHERE (tagId = @tagId)) BEGIN
					SELECT		[message] = 'There is no such tag',
								[success] = CAST(0 AS BIT)
				END ELSE BEGIN
					UPDATE	Tags 
					SET		leasePostId = @leasePostId, 
							tagName = @tagName, 
							tagDescription = @tagDescription
					WHERE tagId = @tagId
					SELECT		[message] = 'Updated',
								[success] = CAST(1 AS BIT)
				END
			END
		END TRY BEGIN CATCH
			IF(@@TRANCOUNT > 0) ROLLBACK TRAN
			DECLARE @errorParams varchar(max) = CONCAT(	   '@tagId = ', @tagId
														,', @leasePostId = ', @leasePostId
														,', @tagName = ', @tagName
														,', @tagDescription	 = ', @tagDescription	
														
													 )
			EXEC spSAVE_Error @params = @errorParams
		END CATCH
	IF(@@TRANCOUNT > 0) COMMIT TRAN
END
GO



/*=========================================================================================================================
	Name:				spDelete_Tag

	Description:		Delete Tag
=========================================================================================================================*/
CREATE PROCEDURE spDelete_Tag
	@tagId						INT
AS BEGIN
	BEGIN TRAN
		BEGIN TRY
			IF NOT EXISTS(SELECT NULL FROM Tags WHERE (tagId = @tagId)) BEGIN
				SELECT		[message] = 'There is no such tag',
							[success] = CAST(0 AS BIT)
			
			END ELSE BEGIN
					DELETE FROM UserTags WHERE tagId = @tagId
					DELETE FROM Tags WHERE tagId = @tagId
					SELECT	[message] = 'Tag deleted',
							[success] = CAST(1 AS BIT)

			END
	
		END TRY BEGIN CATCH
			IF(@@TRANCOUNT > 0) ROLLBACK TRAN

			DECLARE @errorParams varchar(max) = CONCAT(	   '@tagId = ', @tagId														
													  )
			EXEC spSAVE_Error @params = @errorParams
		END CATCH
	IF(@@TRANCOUNT > 0) COMMIT TRAN
END
GO



/*=========================================================================================================================
	Name:				spAddUpdate_PriceType

	Description:		Add/update Price Type
=========================================================================================================================*/
CREATE PROCEDURE spAddUpdate_PriceType
	@priceTypeId				INT,
	@priceTypeDescription		VARCHAR(50)
AS BEGIN
	BEGIN TRAN
		BEGIN TRY
			IF(@priceTypeId = 0) BEGIN																										-- ADD
				IF NOT EXISTS(SELECT NULL FROM PriceTypes WHERE priceTypeDescription = @priceTypeDescription) BEGIN
					INSERT INTO PriceTypes(priceTypeDescription)
					VALUES (@priceTypeDescription)

					SELECT		@@IDENTITY AS priceTypeId,
								[success] = CAST(1 AS BIT),
								[message] = 'Price Type added'

				END ELSE BEGIN
					SELECT		[success] = CAST(0 AS BIT),
								[message] = 'Price Type existed'
				END
			END ELSE BEGIN																													-- UPDATE 
				IF NOT EXISTS(SELECT NULL FROM PriceTypes WHERE (priceTypeId = @priceTypeId)) BEGIN
					SELECT		[message] = 'There is no such tag',
								[success] = CAST(0 AS BIT)
				END ELSE BEGIN
					UPDATE	priceTypes 
					SET		priceTypeDescription = @priceTypeDescription
					WHERE	priceTypeId = @priceTypeId
					SELECT		[message] = 'Updated',
								[success] = CAST(1 AS BIT)
				END
			END
		END TRY BEGIN CATCH
			IF(@@TRANCOUNT > 0) ROLLBACK TRAN
			DECLARE @errorParams varchar(max) = CONCAT(	   '@priceTypeId = ', @priceTypeId
														,', @priceTypeDescription = ', @priceTypeDescription
														
													 )
			EXEC spSAVE_Error @params = @errorParams
		END CATCH
	IF(@@TRANCOUNT > 0) COMMIT TRAN
END
GO



/*=========================================================================================================================
	Name:				spDelete_PriceType

	Description:		Delete PriceType
=========================================================================================================================*/
CREATE PROCEDURE spDelete_PriceType
	@priceTypeId				INT
AS BEGIN
	BEGIN TRAN
		BEGIN TRY
			IF NOT EXISTS(SELECT NULL FROM PriceTypes WHERE (priceTypeId = @priceTypeId)) BEGIN
				SELECT		[message] = 'There is no such price type',
							[success] = CAST(0 AS BIT)
			
			END ELSE BEGIN
				DELETE FROM LeasePostReply 
					WHERE leasePostReplyId IN (	SELECT lpr.leasePostReplyId 
												FROM LeasePostReply lpr 
													JOIN LeasePosts lp ON lpr.leasePostId = lp.leasePostId 
												WHERE lp.priceTypeId = @priceTypeId)
				DELETE FROM LeasePosts WHERE priceTypeId = @priceTypeId
				DELETE FROM PriceTypes WHERE priceTypeId = @priceTypeId
				SELECT		[message] = 'Price Type deleted',
							[success] = CAST(1 AS BIT)

			END
	
		END TRY BEGIN CATCH
			IF(@@TRANCOUNT > 0) ROLLBACK TRAN

			DECLARE @errorParams varchar(max) = CONCAT(	   '@priceTypeId = ', @priceTypeId														
													  )
			EXEC spSAVE_Error @params = @errorParams
		END CATCH
	IF(@@TRANCOUNT > 0) COMMIT TRAN
END
GO

/*=========================================================================================================================
	Name:				spGet_userDue

	Description:		Get a list of users who haven’t returned items before the due date
=========================================================================================================================*/
CREATE PROCEDURE spGet_userDue 
	
AS BEGIN
	SELECT * FROM vwUsers u JOIN vwLeasePostReply lpr ON lpr.userId = u.userId WHERE lpr.borrowEndDate < GETDATE()
END
GO


/*=========================================================================================================================
	Name:				spGet_leasPostsByUser

	Description:		Get a user’s lease posts
=========================================================================================================================*/
CREATE PROCEDURE spGet_leasPostsByUser 
	@userId						   INT
AS BEGIN
	SELECT * FROM vwLeasePosts WHERE userId=@userId
END
GO

/*=========================================================================================================================
	Name:				spGet_replyPosts

	Description:		Get all reply posts of a lease post
=========================================================================================================================*/

CREATE PROCEDURE spGet_replyPosts 
	@leasePostId			  INT
AS BEGIN
	SELECT * FROM vwLeasePostReply WHERE leasePostId=@leasePostId
END
GO

/*=========================================================================================================================
	Name:				spGet_replyLeasPostsByUser

	Description:		Get a user’s  all reply lease posts

=========================================================================================================================*/

CREATE PROCEDURE spGet_replyLeasPostsByUser
	@userId								INT
AS BEGIN
	SELECT * FROM vwLeasePostReply WHERE userId=@userId
END
GO


/*=========================================================================================================================
	Name:				spGet_tagsByLeasePost

	Description:		Get all tags of a lease post

=========================================================================================================================*/

CREATE PROCEDURE spGet_tagsByLeasePost
	@leasePostId				   INT
AS BEGIN
	SELECT * FROM Tags WHERE leasePostId=@leasePostId
END
GO


/*=========================================================================================================================
	Name:				spGet_LeasPostsInPriceRange

	Description:		Get all posts within a price range

=========================================================================================================================*/

CREATE PROCEDURE spGet_LeasPostsInPriceRange
	@lower							  FLOAT,
	@upper							  FLOAT,
	@priceTypeId					    INT
AS BEGIN
	SELECT * FROM LeasePosts WHERE priceTypeId=@priceTypeId AND price BETWEEN @lower AND @upper
END
GO




---------------------------------------------------------------------------------------------------------------------------
----******************* CREATE TRIGGERS
---------------------------------------------------------------------------------------------------------------------------

/*=========================================================================================================================
	Name:				trgLeasePostReplyDateCheck

	Description:		Check if the start date and the end date that users enter after inserting or updating
						are valid or not
=========================================================================================================================*/
CREATE TRIGGER trgLeasePostReplyDateCheck ON LeasePostReply
	AFTER INSERT, UPDATE
AS BEGIN
	IF EXISTS(SELECT NULL FROM inserted WHERE borrowStartDate > borrowEndDate) BEGIN
		RAISERROR(	'The start date must be before the end date',				-- message
					16,											-- severity
					1,											-- state
					'total',									-- param 1
					0											-- parma 2
					)

		ROLLBACK TRANSACTION
	END ELSE IF EXISTS(SELECT NULL FROM inserted JOIN LeasePosts lp ON inserted.leasePostId = lp.leasePostId WHERE inserted.borrowStartDate < lp.leaseStartDate OR inserted.borrowEndDate > lp.leaseEndDate) BEGIN
		RAISERROR(	'The borrow time interval must be inside the lease time interval',				-- message
					16,											-- severity
					1,											-- state
					'total',									-- param 1
					0											-- parma 2
					)
		ROLLBACK TRANSACTION
	END 
END
GO


/*=========================================================================================================================
	Name:				trgLeasePostReplyAmountCheck

	Description:		Check if the amount user wants to borrow is valid or not; that is, smaller or equal to the leased amount
=========================================================================================================================*/
CREATE TRIGGER trgLeasePostReplyAmountCheck ON LeasePostReply
	AFTER INSERT, UPDATE
AS BEGIN
	IF EXISTS(SELECT NULL FROM inserted JOIN LeasePosts lp ON inserted.leasePostId = lp.leasePostId WHERE inserted.amount > lp.itemAmount) BEGIN
		RAISERROR(	'The borrowed amount must be smaller or equal to the leased amount',				-- message
					16,																					-- severity
					1,																					-- state
					'total',																			-- param 1
					0																					-- parma 2
					)

		ROLLBACK TRANSACTION
	END
END
GO



/*=========================================================================================================================
	Name:				trgLeasePostDateCheck

	Description:		Check if the start date and the end date that users enter after inserting or updating
						are valid or not
=========================================================================================================================*/
CREATE TRIGGER trgLeasePostDateCheck ON LeasePosts
	AFTER INSERT, UPDATE
AS BEGIN
	IF EXISTS(SELECT NULL FROM inserted WHERE leaseStartDate > leaseEndDate OR leaseStartDate < dateCreated) BEGIN
		RAISERROR(	'The start date must be before the end date or the start date must be before the date created',				-- message
					16,																											-- severity
					1,																											-- state
					'total',																									-- param 1
					0																											-- param 2
					)

		ROLLBACK TRANSACTION
	END
END
GO


/*=========================================================================================================================
	Name:				trgPricePostiveCheck

	Description:		Check if the price that users enter after inserting or updating
						is valid or not
=========================================================================================================================*/
CREATE TRIGGER trgPricePostiveCheck ON LeasePosts
	AFTER INSERT, UPDATE
AS BEGIN
	IF EXISTS(SELECT NULL FROM inserted WHERE price < 0) BEGIN
		RAISERROR(	'Price %s must be >= %d',				-- message
					16,											-- severity
					1,											-- state
					'total',									-- param 1
					0											-- parma 2
					)

		ROLLBACK TRANSACTION
	END
END
GO


/*=========================================================================================================================
	Name:				trgAmountCheckPositive

	Description:		Check if the price that users enter after inserting or updating
						is valid or not
=========================================================================================================================*/
CREATE TRIGGER trgAmountCheckPositive ON LeasePosts
	AFTER INSERT, UPDATE
AS BEGIN
	IF EXISTS(SELECT NULL FROM inserted WHERE itemAmount < 0) BEGIN
		RAISERROR(	'The amount of item %s must be >= %d',				-- message
					16,													-- severity
					1,													-- state
					'total',											-- param 1
					0													-- parma 2
					)

		ROLLBACK TRANSACTION
	END
END
GO




---------------------------------------------------------------------------------------------------------------------------
----******************* TABLE POPULATION
---------------------------------------------------------------------------------------------------------------------------
-- Users Table
INSERT INTO Users(
	userName,       fName,       lName,                  email,                                          password,  dateOfBirth,        phone, isDeleted
) VALUES 
('nguyenmh',       'Manh',    'Nguyen', 'nguyenmh@miamioh.edu', dbo.fnEncrypt(CAST('8wZKebfRp' AS VARCHAR(4000))), '08-07-1998', '5133289561',         0),
(   'torin',       'Tori',     'Nuani',    'torin@miamioh.edu', dbo.fnEncrypt(CAST('8wZKebfRp' AS VARCHAR(4000))), '08-07-1998', '5133289562',         0),
(    'frek',       'Fred', 'Kerringer',     'frek@miamioh.edu', dbo.fnEncrypt(CAST('8wZKebfRp' AS VARCHAR(4000))), '08-07-1998', '5133289563',         0),
(  'corona',       'Coro',        'Na',   'corona@miamioh.edu', dbo.fnEncrypt(CAST('8wZKebfRp' AS VARCHAR(4000))), '08-07-1998', '5133289564',         0),
(   'jaswu',      'Jason',        'Wu',    'jaswu@miamioh.edu', dbo.fnEncrypt(CAST('8wZKebfRp' AS VARCHAR(4000))), '08-07-1998', '5133289565',         0),
(    'liom',     'Lionel',     'Messi',     'liom@miamioh.edu', dbo.fnEncrypt(CAST('8wZKebfRp' AS VARCHAR(4000))), '08-07-1998', '5133289566',         0),
(     'cr7', 'Christiano',   'Ronaldo',      'cr7@miamioh.edu', dbo.fnEncrypt(CAST('8wZKebfRp' AS VARCHAR(4000))), '08-07-1998', '5133289567',         0),
(   'mickj',    'Michael',   'Jackson',    'mickj@miamioh.edu', dbo.fnEncrypt(CAST('8wZKebfRp' AS VARCHAR(4000))), '08-07-1998', '5133289568',         0),
(  'anthom',    'Anthony',   'Martial',   'anthom@miamioh.edu', dbo.fnEncrypt(CAST('8wZKebfRp' AS VARCHAR(4000))), '08-07-1998', '5133289569',         0),
(  'robcar',    'Roberto',    'Carlos',   'robcar@miamioh.edu', dbo.fnEncrypt(CAST('8wZKebfRp' AS VARCHAR(4000))), '08-07-1998', '5133289560',         0);


-- PriceTypes Table
INSERT INTO PriceTypes (priceTypeDescription) VALUES ('daily'), ('weekly'), ('monthly'), ('annually');

INSERT INTO LeasePosts (
	userId, priceTypeId,                description,         condition, itemAmount, leaseStartDate, leaseEndDate, price, dateCreated, isDeleted)
VALUES 
(		 1,           1,      'awesome soccer ball',             'new',          3,     '5-4-2020',  '5-10-2020',  14.5,  '1-1-2020',		  0),
(        2,           2,       'awesome volleyball',             'old',         13,     '5-3-2020',  '5-10-2020',  12.5,  '1-1-2020',		  0),
(        3,           3,      'awesome tennis ball',        'very old',          7,		'5-2-2020',  '8-10-2020',  19.5,  '1-1-2020',		  0),
(        4,           4,       'awesome basketball',        'very new',          5,		'5-1-2020',  '9-10-2020',  34.5,  '1-1-2020',		  0),
(        5,           1, 'awesome lacrosse racquet',             'new',          2,	   '5-18-2020', '10-10-2020',  24.5,  '1-1-2020',		  0),
(        6,           2,    'awesome pingpong ball', 'not new not old',          1,		'4-4-2020', '11-10-2020',  45.5,  '1-1-2020',		  0),
(        7,           3,          'awesome monitor',             'new',          3,		'3-4-2020', '12-10-2020',  65.3,  '1-1-2020',		  0),
(        8,           4,           'awesome laptop',             'old',          3,		'2-4-2020',   '7-7-2020',  21.8,  '1-1-2020',		  0),
(        9,           1,        'awesome headphone',             'new',        123,		'2-4-2020',   '8-8-2020',  18.2,  '1-1-2020',		  0),
(       10,           2,           'awesome airpod',             'new',         12,	   '2-18-2020',   '6-6-2020',  19.7,  '1-1-2020',		  0),
(        1,           3,            'awesome glass',             'new',          9,		'1-4-2020',   '5-6-2020',  14.1,  '1-1-2020',		  0),
(        1,           4,           'awesome wallet',             'new',          3,	   '1-12-2020',  '5-10-2020',  31.2,  '1-1-2020',		  0),
(        1,           1,              'awesome fan',             'old',          7,		'1-9-2020',   '5-9-2020',  61.0,  '1-1-2020',		  0),
(        2,           2,            'awesome yatch',         'ancient',          6,		'3-7-2020',  '5-22-2020',  34.0,  '1-1-2020',		  0),
(        2,           3,              'awesome hat',             'new',          3,	   '3-14-2020',  '4-10-2020',  22.5,  '1-1-2020',		  0),
(        3,           4,          'awesome speaker',             'old',          1,	   '3-27-2020',  '5-10-2020',  78.9,  '1-1-2020',		  0);

-- ItemURLs Table
INSERT INTO ItemURLs
	(leasePostId,	   pictureURL)
VALUES 
(			   1,  'picture0.png'), 
(			   2,  'picture1.png'), 
(			   3,  'picture2.png'), 
(			   4,  'picture3.png'), 
(			   5,  'picture4.png'), 
(			   6,  'picture5.png'), 
(			   7,  'picture6.png'), 
(			   8,  'picture7.png'), 
(			   9,  'picture8.png'), 
(			  10,  'picture9.png'), 
(			  11, 'picture10.png'), 
(			  12, 'picture11.png'), 
(			  13, 'picture12.png'), 
(			  14, 'picture13.png'), 
(			  15, 'picture14.png'), 
(			  16, 'picture15.png'), 
(			   1, 'picture16.png'), 
(			   1, 'picture17.png'), 
(			   1, 'picture18.png'), 
(			   1, 'picture19.png'); 

-- Tages Table
INSERT INTO Tags
	(leasePostId,			tagName) 
VALUES 
(		       1, 'sport equipment'),
(			   2,		'appliance'),
(			   3,		  'utensil'),
(			   4,		  'vehicle'),
(			   5,		   'weapon'),
(			   6,		  'clothes'),
(			   7,		 'computer'),
(			   8,	         'food'),
(			   9,	   'stationery'),
(			  10,		'furniture');

-- UserTags Table
INSERT INTO UserTags 
	(tagId, userId) 
VALUES 
(	     1,      1),
(		 2,		 2),
(		 3,		 3),
(		 4,		 4),
(		 5,		 5),
(		 6,		 6),
(		 7,		 7),
(		 8,		 8),
(		 9,		 9),
(		 10,	10);


-- Address Table
INSERT INTO Address 
	(userId,				   address1, address2,			  city, [state], postalCode, country, isDeleted)
VALUES 
(		  1,	  '600 S Locust Street',	   '',	      'Oxford',    'OH',	  45056,   'USA',		  0),
(		  2,	  '600 N Poplar Street',	   '',		  'Oxford',	   'OH',	  45056,   'USA',         0),
(		  3,		 '600 Maple Street',	   '',		  'Oxford',	   'OH',	  45056,   'USA',         0),
(		  4, '600 Amphitheatre Parkway',	   '', 'Mountain View',    'CA',	  85056,   'USA',         0),
(		  5,		   '600 Oak Street',	   '', 'Mountain View',    'CA',	  85056,   'USA',         0),
(		  6,		'600 Midway Street',	   '', 'San Francisco',    'CA',	  25056,   'USA',         0),
(		  7,	   '600 Concord Street',	   '', 'San Francisco',    'CA',	  25056,   'USA',         0),
(		  8,		'600 Willow Street',	   '',	   'Ann Arbor',    'MI',	  75056,   'USA',         0),
(		  9,	  '600 Fairfield Drive',	   '',	   'Ann Arbor',    'MI',	  75056,   'USA',         0),
(		 10,	   '600 Tollgate Drive',	   '',	   'Ann Arbor',    'MI',	  75056,   'USA',         0);


-- LeasePostReply Table
INSERT INTO LeasePostReply
	(userId, addressId, leasePostId,				[message], borrowStartDate, borrowEndDate, amount, [status], isDeleted)
VALUES 
(	     10,	    10,			  1, 'please can i borrow it',		'5-4-2020',   '5-10-2020',	    1,	    'p',		 0),
(		  9,		 9,			  2, 'please can i borrow it',		'5-4-2020',   '5-10-2020',      1,      'c',		 0),
(		  8,		 8,			  3, 'please can i borrow it',		'5-2-2020',   '8-10-2020',      1,      'p',		 0),
(		  7,		 7,			  4, 'please can i borrow it',		'5-1-2020',   '9-10-2020',      1,      'c',		 0),
(		  6,		 6,			  5, 'please can i borrow it',	   '5-18-2020',  '10-10-2020',      1,      'c',		 0),
(		  5,		 5,			  6, 'please can i borrow it',	    '4-4-2020',  '11-10-2020',      1,		'p',		 0),
(		  4,		 4,			  7, 'please can i borrow it',	    '3-4-2020',  '12-10-2020',      1,		'p',		 0),
(		  3,		 3,			  8, 'please can i borrow it',	    '2-4-2020',    '7-7-2020',      1,		'p',		 0),
(		  2,		 2,			  9, 'please can i borrow it',      '2-4-2020',    '8-8-2020',      1,		'p',		 0),
(		  1,		 1,			 10, 'please can i borrow it',     '2-18-2020',    '6-6-2020',      1,		'p',		 0),
(		  4,		 4,		     11, 'please can i borrow it',      '1-4-2020',    '5-6-2020',      1,		'c',		 0),
(		  4,		 4,			 12, 'please can i borrow it',	   '1-12-2020',   '5-10-2020',      1,		'p',		 0),
(		  4,		 4,			 13, 'please can i borrow it',      '1-9-2020',    '5-9-2020',      1,		'p',		 0),
(		  5,		 5,			 14, 'please can i borrow it',      '3-7-2020',   '5-22-2020',      1,		'c',		 0),
(		  5,		 5,			 15, 'please can i borrow it',     '3-14-2020',   '4-10-2020',      1,		'p',		 0),
(		  6,		 6,			 16, 'please can i borrow it',     '3-27-2020',   '5-10-2020',      1,		'p',		 0);






-------------------------------------------------------------------------------------------------------------------------
--******************* TEST CALLS TO STORED PROCEDURES
-------------------------------------------------------------------------------------------------------------------------

--Add user
EXEC	spAddUpdateDelete_User	@userId = 0, @userName = 'AugustD', @fName = 'August', @lName = 'Dann', @email = 'anday2324@gmail.com', 
								@password = 'QtUH0YsD1D', @phone='0123456789', @dateOfBirth = '03/08/1978'

-- Update user

EXEC	spAddUpdateDelete_User	@userId = 11, @userName = 'ADann', @fName = 'August', @lName = 'Dann', @email = 'anday2324@gmail.com', 
								@password = 'QtUH0YsD1D', @phone='0123456789', @dateOfBirth = '03/08/1978'

-- Delete user
EXEC	spAddUpdateDelete_User	@userId = 11, @userName = 'AugustD', @fName = 'August', @lName = 'Dann', @email = 'anday2324@gmail.com', 
								@password = 'QtUH0YsD1D', @phone='0123456789', @dateOfBirth = '03/08/1978', @isDeleted=1


---- Add Address 
EXEC	spAddUpdateDelete_Address @addressId = 0, @userId = 1, @address1 = '610 Oxford Commons', @address2 = '10 Miami Commons', 
							@city = 'Oxford', @state = 'Ohio', @postalCode = 45056, @country ='England'

---- Update Address 
EXEC	spAddUpdateDelete_Address @addressId = 11, @userId = 1, @address1 = '610 Oxford Commons', @address2 = '10 Miami Commons', 
							@city = 'Oxford', @state = 'Ohio', @postalCode = 45056, @country ='USA'

-- Delete Address
EXEC	spAddUpdateDelete_Address @addressId = 11, @userId = 1, @address1 = '610 Oxford Commons', @address2 = '10 Miami Commons', 
							@city = 'Oxford', @state = 'Ohio', @postalCode = 45056, @country ='USA', @isDeleted=1


-- Add LeasePostReply
EXEC	spAddUpdateDelete_LeasePostReply	@leasePostReplyId = 0, @userId = 5, @addressId = 5, @leasePostId = 11, @message = 'I want to borrow', 
											@borrowStartDate = '2020-01-04', @borrowEndDate = '2020-05-06', @amount = 1, @status = 'p'

-- Update LeasePostReply
EXEC	spAddUpdateDelete_LeasePostReply	@leasePostReplyId = 17, @userId = 5, @addressId = 5, @leasePostId = 11, @message = 'I want to borrow', 
											@borrowStartDate = '2020-04-06', @borrowEndDate = '2020-04-06', @amount = 1, @status = 'p'

-- Delete LeasePostReply
EXEC	spAddUpdateDelete_LeasePostReply	@leasePostReplyId = 17, @userId = 5, @addressId = 5, @leasePostId = 11, @message = 'I want to borrow', 
											@borrowStartDate = '2020-01-04', @borrowEndDate = '2020-05-06', @amount = 1, @status = 'p', @isDeleted = 1


-- Add LeasePost
EXEC	spAddUpdateDelete_LeasePost	@leasePostId = 0, @userId = 4, @priceTypeId = 3, @description = 'iPhone', 
									@condition = 'new', @itemAmount = 1, @leaseStartDate = '2020-04-19', @leaseEndDate = '2020-05-30', @price = 50, @dateCreated = '2020-04-18'

-- Update LeasePost
EXEC	spAddUpdateDelete_LeasePost	@leasePostId = 17, @userId = 4, @priceTypeId = 2, @description = 'iPhone', 
									@condition = 'new', @itemAmount = 1, @leaseStartDate = '2020-04-19', @leaseEndDate = '2020-05-30', @price = 50, @dateCreated = '2020-04-18'

-- Delete LeasePost
EXEC	spAddUpdateDelete_LeasePost	@leasePostId = 17, @userId = 5, @priceTypeId = 2, @description = 'iPhone', 
									@condition = 'new', @itemAmount = 1, @leaseStartDate = '2020-04-19', @leaseEndDate = '2020-05-30', @price = 50, @dateCreated = '2020-04-18',
									@isDeleted = 1

-- Add Tag
EXEC spAddUpdate_Tag @tagId = 0, @leasePostId = 5, @tagName = 'vehicle', @tagDescription = ''

-- Update Tag
EXEC spAddUpdate_Tag @tagId = 11, @leasePostId = 5, @tagName = 'vehicle', @tagDescription = 'Some description'

-- Delete Tag
EXEC spDelete_Tag @tagId = 11

-- Add PriceType
EXEC spAddUpdate_PriceType @priceTypeId = 0, @priceTypeDescription = 'quarterly'

-- Update PriceType
EXEC spAddUpdate_PriceType @priceTypeId = 5, @priceTypeDescription = 'biweekly'

-- Delete PriceType
EXEC spDelete_PriceType @priceTypeId = 5

-- Test spGet_userDue: Get all users whose has gone over their borrow time
EXEC spGet_userDue

-- Test spGet_LeasPostByUser: Get all lease posts from an user
EXEC spGet_leasPostsByUser @userId = 1

-- Test spGet_replyPosts: Get all reply post of a lease post
EXEC spGet_replyPosts @leasePostId = 1

-- Test spGet_replyLeasPostsByUser: get all reply lease posts from an user
EXEC spGet_replyLeasPostsByUser @userId = 4

-- Test spGet_tagsByLeasePost: get all tags of a lease post
EXEC spGet_tagsByLeasePost @leasePostId = 1


-- Test spGet_LeasPostsInPriceRange: get all lease posts whose price are between the interval
EXEC spGet_LeasPostsInPriceRange @lower = 1.0, @upper = 20.0, @priceTypeId = 1

