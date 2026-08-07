SET lock_timeout = '2s';
SET statement_timeout = '5min';
SET application_name = 'migrate:init';
SET idle_in_transaction_session_timeout = '30s';

CREATE TABLE "User" (
    "id" SERIAL NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "User_email_key" ON "User"("email");
