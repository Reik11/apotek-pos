--
-- PostgreSQL database dump
--

\restrict QUhczu0BKNm9PrUGPdjrvE8i9ZaijHfYJmBqOmYDDHGxLPD7g3ijlkSaB9sAxsm

-- Dumped from database version 16.14 (Debian 16.14-1.pgdg13+1)
-- Dumped by pg_dump version 16.14 (Debian 16.14-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: DrugCategory; Type: TYPE; Schema: public; Owner: apotek_user
--

CREATE TYPE public."DrugCategory" AS ENUM (
    'BEBAS',
    'BEBAS_TERBATAS',
    'KERAS',
    'NARKOTIKA',
    'PSIKOTROPIKA'
);


ALTER TYPE public."DrugCategory" OWNER TO apotek_user;

--
-- Name: DrugType; Type: TYPE; Schema: public; Owner: apotek_user
--

CREATE TYPE public."DrugType" AS ENUM (
    'GENERIK',
    'PATEN',
    'BPJS'
);


ALTER TYPE public."DrugType" OWNER TO apotek_user;

--
-- Name: OrderStatus; Type: TYPE; Schema: public; Owner: apotek_user
--

CREATE TYPE public."OrderStatus" AS ENUM (
    'PENDING',
    'CONFIRMED',
    'PREPARING',
    'READY',
    'COMPLETED',
    'CANCELLED'
);


ALTER TYPE public."OrderStatus" OWNER TO apotek_user;

--
-- Name: PaymentMethod; Type: TYPE; Schema: public; Owner: apotek_user
--

CREATE TYPE public."PaymentMethod" AS ENUM (
    'CASH',
    'TRANSFER',
    'QRIS',
    'DEBIT',
    'CREDIT'
);


ALTER TYPE public."PaymentMethod" OWNER TO apotek_user;

--
-- Name: Role; Type: TYPE; Schema: public; Owner: apotek_user
--

CREATE TYPE public."Role" AS ENUM (
    'SUPER_ADMIN',
    'ADMIN',
    'APOTEKER',
    'KASIR',
    'PASIEN'
);


ALTER TYPE public."Role" OWNER TO apotek_user;

--
-- Name: TxStatus; Type: TYPE; Schema: public; Owner: apotek_user
--

CREATE TYPE public."TxStatus" AS ENUM (
    'COMPLETED',
    'CANCELLED',
    'REFUNDED'
);


ALTER TYPE public."TxStatus" OWNER TO apotek_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: Drug; Type: TABLE; Schema: public; Owner: apotek_user
--

CREATE TABLE public."Drug" (
    id text NOT NULL,
    name text NOT NULL,
    "genericName" text,
    "brandName" text,
    "activeIngredient" text,
    category public."DrugCategory" DEFAULT 'BEBAS'::public."DrugCategory" NOT NULL,
    type public."DrugType" DEFAULT 'GENERIK'::public."DrugType" NOT NULL,
    unit text DEFAULT 'tablet'::text NOT NULL,
    "minStock" integer DEFAULT 10 NOT NULL,
    "sellPrice" double precision NOT NULL,
    "buyPrice" double precision NOT NULL,
    rxcui text,
    "bpomNumber" text,
    description text,
    "isActive" boolean DEFAULT true NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."Drug" OWNER TO apotek_user;

--
-- Name: DrugBatch; Type: TABLE; Schema: public; Owner: apotek_user
--

CREATE TABLE public."DrugBatch" (
    id text NOT NULL,
    "drugId" text NOT NULL,
    "batchNumber" text NOT NULL,
    stock integer NOT NULL,
    "buyPrice" double precision NOT NULL,
    "expiredDate" timestamp(3) without time zone NOT NULL,
    "receivedDate" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "supplierId" text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."DrugBatch" OWNER TO apotek_user;

--
-- Name: OcrScan; Type: TABLE; Schema: public; Owner: apotek_user
--

CREATE TABLE public."OcrScan" (
    id text NOT NULL,
    "userId" text NOT NULL,
    "imageUrl" text,
    "rawText" text,
    "parsedDrugs" jsonb,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."OcrScan" OWNER TO apotek_user;

--
-- Name: Order; Type: TABLE; Schema: public; Owner: apotek_user
--

CREATE TABLE public."Order" (
    id text NOT NULL,
    "patientId" text NOT NULL,
    "totalAmount" double precision NOT NULL,
    status public."OrderStatus" DEFAULT 'PENDING'::public."OrderStatus" NOT NULL,
    "orderCode" text NOT NULL,
    "paymentProof" text,
    notes text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."Order" OWNER TO apotek_user;

--
-- Name: OrderItem; Type: TABLE; Schema: public; Owner: apotek_user
--

CREATE TABLE public."OrderItem" (
    id text NOT NULL,
    "orderId" text NOT NULL,
    "drugId" text NOT NULL,
    quantity integer NOT NULL,
    price double precision NOT NULL,
    subtotal double precision NOT NULL
);


ALTER TABLE public."OrderItem" OWNER TO apotek_user;

--
-- Name: Supplier; Type: TABLE; Schema: public; Owner: apotek_user
--

CREATE TABLE public."Supplier" (
    id text NOT NULL,
    name text NOT NULL,
    phone text,
    email text,
    address text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."Supplier" OWNER TO apotek_user;

--
-- Name: Transaction; Type: TABLE; Schema: public; Owner: apotek_user
--

CREATE TABLE public."Transaction" (
    id text NOT NULL,
    "cashierId" text NOT NULL,
    "totalAmount" double precision NOT NULL,
    "paymentMethod" public."PaymentMethod" DEFAULT 'CASH'::public."PaymentMethod" NOT NULL,
    "amountPaid" double precision NOT NULL,
    change double precision DEFAULT 0 NOT NULL,
    status public."TxStatus" DEFAULT 'COMPLETED'::public."TxStatus" NOT NULL,
    notes text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."Transaction" OWNER TO apotek_user;

--
-- Name: TransactionItem; Type: TABLE; Schema: public; Owner: apotek_user
--

CREATE TABLE public."TransactionItem" (
    id text NOT NULL,
    "transactionId" text NOT NULL,
    "drugId" text NOT NULL,
    "batchId" text NOT NULL,
    quantity integer NOT NULL,
    "sellPrice" double precision NOT NULL,
    subtotal double precision NOT NULL
);


ALTER TABLE public."TransactionItem" OWNER TO apotek_user;

--
-- Name: User; Type: TABLE; Schema: public; Owner: apotek_user
--

CREATE TABLE public."User" (
    id text NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    password text NOT NULL,
    role public."Role" DEFAULT 'KASIR'::public."Role" NOT NULL,
    "isActive" boolean DEFAULT true NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."User" OWNER TO apotek_user;

--
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: apotek_user
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public._prisma_migrations OWNER TO apotek_user;

--
-- Data for Name: Drug; Type: TABLE DATA; Schema: public; Owner: apotek_user
--

COPY public."Drug" (id, name, "genericName", "brandName", "activeIngredient", category, type, unit, "minStock", "sellPrice", "buyPrice", rxcui, "bpomNumber", description, "isActive", "createdAt", "updatedAt") FROM stdin;
e9e06c8b-18ba-4bf8-928f-b71577a8fe4c	Amoxicillin 500mg	Amoxicillin	\N	Amoxicillin trihydrate	KERAS	GENERIK	kapsul	20	2000	1900	\N	\N	Antibiotik untuk infeksi bakteri	t	2026-05-31 19:08:20.043	2026-06-02 21:01:19.893
\.


--
-- Data for Name: DrugBatch; Type: TABLE DATA; Schema: public; Owner: apotek_user
--

COPY public."DrugBatch" (id, "drugId", "batchNumber", stock, "buyPrice", "expiredDate", "receivedDate", "supplierId", "createdAt") FROM stdin;
81725c17-62db-4bdb-90ad-8799123a0d6d	e9e06c8b-18ba-4bf8-928f-b71577a8fe4c	BATCH001	223	1500	2027-12-31 00:00:00	2026-05-31 19:30:09.314	\N	2026-05-31 19:30:09.314
c43f9295-502d-41b0-a225-ec08dae038d0	e9e06c8b-18ba-4bf8-928f-b71577a8fe4c	BATCH001	23	1500	2027-12-31 00:00:00	2026-05-31 19:30:10.093	\N	2026-05-31 19:30:10.093
0e6fae7d-d082-4583-a283-0a9259e966ab	e9e06c8b-18ba-4bf8-928f-b71577a8fe4c	BATCH001	24	1500	2027-12-31 00:00:00	2026-05-31 19:29:15.439	\N	2026-05-31 19:29:15.439
cdf03108-31fc-42e7-af07-09f6a4128195	e9e06c8b-18ba-4bf8-928f-b71577a8fe4c	BATCH001	12	1500	2027-12-31 00:00:00	2026-05-31 19:29:23.062	\N	2026-05-31 19:29:23.062
b772de20-9308-4749-9cec-ee1deb9d0b4c	e9e06c8b-18ba-4bf8-928f-b71577a8fe4c		22	1900	2027-06-03 00:00:00	2026-06-02 22:25:51.746	\N	2026-06-02 22:25:51.746
61895796-538d-439c-9f60-74e7326c99cb	e9e06c8b-18ba-4bf8-928f-b71577a8fe4c		2	1900	2027-06-03 00:00:00	2026-06-02 22:37:29.313	\N	2026-06-02 22:37:29.313
41083dd5-f6d8-4eac-80b1-3268065019c3	e9e06c8b-18ba-4bf8-928f-b71577a8fe4c		2	1900	2027-06-03 00:00:00	2026-06-02 22:40:36.508	\N	2026-06-02 22:40:36.508
\.


--
-- Data for Name: OcrScan; Type: TABLE DATA; Schema: public; Owner: apotek_user
--

COPY public."OcrScan" (id, "userId", "imageUrl", "rawText", "parsedDrugs", "createdAt") FROM stdin;
\.


--
-- Data for Name: Order; Type: TABLE DATA; Schema: public; Owner: apotek_user
--

COPY public."Order" (id, "patientId", "totalAmount", status, "orderCode", "paymentProof", notes, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: OrderItem; Type: TABLE DATA; Schema: public; Owner: apotek_user
--

COPY public."OrderItem" (id, "orderId", "drugId", quantity, price, subtotal) FROM stdin;
\.


--
-- Data for Name: Supplier; Type: TABLE DATA; Schema: public; Owner: apotek_user
--

COPY public."Supplier" (id, name, phone, email, address, "createdAt") FROM stdin;
\.


--
-- Data for Name: Transaction; Type: TABLE DATA; Schema: public; Owner: apotek_user
--

COPY public."Transaction" (id, "cashierId", "totalAmount", "paymentMethod", "amountPaid", change, status, notes, "createdAt") FROM stdin;
ca2cc369-e34d-463e-b478-c6b449d561e7	4b28310e-fce8-4e48-91ec-9146d3e83b2b	5000	CASH	10000	5000	COMPLETED	\N	2026-05-31 19:31:44.887
2f1bfa14-c2be-406d-802b-39055a11e5b7	4b28310e-fce8-4e48-91ec-9146d3e83b2b	2500	QRIS	2500	0	COMPLETED	\N	2026-06-02 17:10:49.589
4b185399-5722-44d1-bf54-575c870c2d85	4b28310e-fce8-4e48-91ec-9146d3e83b2b	2500	CASH	2500	0	COMPLETED	\N	2026-06-02 17:13:42.937
\.


--
-- Data for Name: TransactionItem; Type: TABLE DATA; Schema: public; Owner: apotek_user
--

COPY public."TransactionItem" (id, "transactionId", "drugId", "batchId", quantity, "sellPrice", subtotal) FROM stdin;
886eb1a3-ba2d-46f1-94ef-22c474e72b4d	ca2cc369-e34d-463e-b478-c6b449d561e7	e9e06c8b-18ba-4bf8-928f-b71577a8fe4c	0e6fae7d-d082-4583-a283-0a9259e966ab	2	2500	5000
2fac8c16-03a5-49e5-9afd-ab14c02490c8	2f1bfa14-c2be-406d-802b-39055a11e5b7	e9e06c8b-18ba-4bf8-928f-b71577a8fe4c	cdf03108-31fc-42e7-af07-09f6a4128195	1	2500	2500
0bcc77bc-92bd-4c06-a936-44aa43fff1e7	4b185399-5722-44d1-bf54-575c870c2d85	e9e06c8b-18ba-4bf8-928f-b71577a8fe4c	81725c17-62db-4bdb-90ad-8799123a0d6d	1	2500	2500
\.


--
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: apotek_user
--

COPY public."User" (id, name, email, password, role, "isActive", "createdAt", "updatedAt") FROM stdin;
4b28310e-fce8-4e48-91ec-9146d3e83b2b	Admin Apotek	admin@apotek.com	$2b$10$4d97xONX8o9jCYbMtxDHWOT1iGsZuodi07q3OL1ps0mSW2t8eQlDC	ADMIN	t	2026-05-31 18:46:50.316	2026-05-31 18:46:50.316
c68c44d3-ef1a-4365-ab7e-1b93b95713a9	Budi Pasien	budi@gmail.com	$2b$10$Vsin9vLU708N/j/pR8Sfxusvd8GS8tjXwxtoPnALpaxaUr1hxWx/m	PASIEN	t	2026-06-01 05:00:55.517	2026-06-01 05:00:55.517
\.


--
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: apotek_user
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
f172a974-da37-41e3-bf9e-9e800fbec043	1cac5f9496a03a48280d0a9b38bbf7e2866d80e0004af2943e210f8a23117b11	2026-05-31 18:28:21.945809+00	20260531182821_init	\N	\N	2026-05-31 18:28:21.737445+00	1
\.


--
-- Name: DrugBatch DrugBatch_pkey; Type: CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."DrugBatch"
    ADD CONSTRAINT "DrugBatch_pkey" PRIMARY KEY (id);


--
-- Name: Drug Drug_pkey; Type: CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."Drug"
    ADD CONSTRAINT "Drug_pkey" PRIMARY KEY (id);


--
-- Name: OcrScan OcrScan_pkey; Type: CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."OcrScan"
    ADD CONSTRAINT "OcrScan_pkey" PRIMARY KEY (id);


--
-- Name: OrderItem OrderItem_pkey; Type: CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."OrderItem"
    ADD CONSTRAINT "OrderItem_pkey" PRIMARY KEY (id);


--
-- Name: Order Order_pkey; Type: CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."Order"
    ADD CONSTRAINT "Order_pkey" PRIMARY KEY (id);


--
-- Name: Supplier Supplier_pkey; Type: CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."Supplier"
    ADD CONSTRAINT "Supplier_pkey" PRIMARY KEY (id);


--
-- Name: TransactionItem TransactionItem_pkey; Type: CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."TransactionItem"
    ADD CONSTRAINT "TransactionItem_pkey" PRIMARY KEY (id);


--
-- Name: Transaction Transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."Transaction"
    ADD CONSTRAINT "Transaction_pkey" PRIMARY KEY (id);


--
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (id);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: Order_orderCode_key; Type: INDEX; Schema: public; Owner: apotek_user
--

CREATE UNIQUE INDEX "Order_orderCode_key" ON public."Order" USING btree ("orderCode");


--
-- Name: User_email_key; Type: INDEX; Schema: public; Owner: apotek_user
--

CREATE UNIQUE INDEX "User_email_key" ON public."User" USING btree (email);


--
-- Name: DrugBatch DrugBatch_drugId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."DrugBatch"
    ADD CONSTRAINT "DrugBatch_drugId_fkey" FOREIGN KEY ("drugId") REFERENCES public."Drug"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: DrugBatch DrugBatch_supplierId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."DrugBatch"
    ADD CONSTRAINT "DrugBatch_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES public."Supplier"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: OcrScan OcrScan_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."OcrScan"
    ADD CONSTRAINT "OcrScan_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: OrderItem OrderItem_drugId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."OrderItem"
    ADD CONSTRAINT "OrderItem_drugId_fkey" FOREIGN KEY ("drugId") REFERENCES public."Drug"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: OrderItem OrderItem_orderId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."OrderItem"
    ADD CONSTRAINT "OrderItem_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES public."Order"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Order Order_patientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."Order"
    ADD CONSTRAINT "Order_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: TransactionItem TransactionItem_batchId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."TransactionItem"
    ADD CONSTRAINT "TransactionItem_batchId_fkey" FOREIGN KEY ("batchId") REFERENCES public."DrugBatch"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: TransactionItem TransactionItem_drugId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."TransactionItem"
    ADD CONSTRAINT "TransactionItem_drugId_fkey" FOREIGN KEY ("drugId") REFERENCES public."Drug"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: TransactionItem TransactionItem_transactionId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."TransactionItem"
    ADD CONSTRAINT "TransactionItem_transactionId_fkey" FOREIGN KEY ("transactionId") REFERENCES public."Transaction"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Transaction Transaction_cashierId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: apotek_user
--

ALTER TABLE ONLY public."Transaction"
    ADD CONSTRAINT "Transaction_cashierId_fkey" FOREIGN KEY ("cashierId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict QUhczu0BKNm9PrUGPdjrvE8i9ZaijHfYJmBqOmYDDHGxLPD7g3ijlkSaB9sAxsm

