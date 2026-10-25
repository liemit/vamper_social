-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Máy chủ: localhost:3306
-- Thời gian đã tạo: Th10 25, 2026 lúc 04:36 PM
-- Phiên bản máy phục vụ: 8.0.30
-- Phiên bản PHP: 8.1.10

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Cơ sở dữ liệu: `vamper_social`
--

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `blocked_users`
--

CREATE TABLE IF NOT EXISTS `blocked_users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `blocker_id` int NOT NULL,
  `blocked_id` int NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_block` (`blocker_id`,`blocked_id`),
  KEY `idx_blocker` (`blocker_id`),
  KEY `idx_blocked` (`blocked_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `card_swipes`
--

CREATE TABLE `card_swipes` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `target_id` int NOT NULL,
  `action` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'pass, like, superlike',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `card_swipes`
--

INSERT INTO `card_swipes` (`id`, `user_id`, `target_id`, `action`, `created_at`) VALUES
(1, 15, 106, 'pass', '2026-10-12 14:47:09'),
(2, 15, 14, 'pass', '2026-10-12 14:47:11'),
(3, 15, 113, 'pass', '2026-10-12 14:47:13'),
(4, 15, 103, 'pass', '2026-10-12 14:47:15'),
(5, 15, 116, 'pass', '2026-10-12 14:47:16'),
(6, 15, 16, 'pass', '2026-10-12 14:47:17'),
(7, 15, 102, 'pass', '2026-10-12 14:47:18'),
(8, 15, 115, 'pass', '2026-10-12 14:47:18'),
(9, 15, 101, 'pass', '2026-10-12 14:47:19'),
(10, 15, 105, 'pass', '2026-10-12 14:47:20'),
(11, 15, 107, 'pass', '2026-10-12 14:47:21'),
(12, 15, 108, 'pass', '2026-10-12 14:47:21'),
(13, 15, 104, 'pass', '2026-10-12 14:47:22'),
(14, 125, 123, 'pass', '2026-10-18 12:08:50'),
(15, 125, 102, 'pass', '2026-10-18 12:08:52'),
(16, 125, 105, 'pass', '2026-10-18 12:08:53'),
(17, 125, 117, 'pass', '2026-10-18 12:08:54'),
(18, 125, 101, 'pass', '2026-10-18 12:08:54'),
(19, 125, 113, 'pass', '2026-10-18 12:08:55'),
(20, 125, 118, 'pass', '2026-10-18 12:08:55'),
(21, 16, 128, 'pass', '2026-10-25 13:21:15'),
(22, 16, 15, 'pass', '2026-10-25 13:21:16'),
(23, 16, 104, 'pass', '2026-10-25 13:21:17'),
(24, 16, 129, 'pass', '2026-10-25 13:21:17'),
(25, 16, 103, 'pass', '2026-10-25 13:21:18'),
(26, 16, 113, 'pass', '2026-10-25 13:21:18'),
(27, 16, 118, 'pass', '2026-10-25 13:21:18'),
(28, 16, 105, 'pass', '2026-10-25 13:21:18'),
(29, 16, 102, 'pass', '2026-10-25 13:21:19'),
(30, 16, 116, 'pass', '2026-10-25 13:21:19'),
(31, 16, 127, 'pass', '2026-10-25 13:21:20'),
(32, 16, 107, 'pass', '2026-10-25 13:21:20'),
(33, 16, 101, 'pass', '2026-10-25 13:21:20'),
(34, 16, 119, 'pass', '2026-10-25 13:21:20'),
(35, 16, 117, 'pass', '2026-10-25 13:21:21'),
(36, 16, 108, 'pass', '2026-10-25 13:21:21'),
(37, 15, 129, 'pass', '2026-10-25 14:25:43'),
(38, 15, 119, 'pass', '2026-10-25 14:25:43'),
(39, 15, 127, 'pass', '2026-10-25 14:25:44'),
(40, 15, 117, 'pass', '2026-10-25 14:25:44'),
(41, 15, 128, 'pass', '2026-10-25 14:25:45'),
(42, 15, 118, 'pass', '2026-10-25 14:25:46');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `comment_interactions`
--

CREATE TABLE `comment_interactions` (
  `id` int NOT NULL,
  `comment_id` int NOT NULL,
  `user_id` int NOT NULL,
  `interaction_type` enum('like','dislike') COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `conversations`
--

CREATE TABLE `conversations` (
  `id` int NOT NULL,
  `user1_id` int NOT NULL,
  `user2_id` int NOT NULL,
  `last_message` text COLLATE utf8mb4_unicode_ci,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `conversations`
--

INSERT INTO `conversations` (`id`, `user1_id`, `user2_id`, `last_message`, `updated_at`) VALUES
(1, 15, 105, '2', '2026-10-14 15:44:16'),
(2, 15, 104, '1', '2026-10-14 15:43:57'),
(3, 15, 102, '3', '2026-10-14 15:44:29'),
(4, 15, 101, '4', '2026-10-14 15:44:45'),
(5, 15, 103, '5', '2026-10-14 15:44:58'),
(6, 15, 107, '7', '2026-10-14 15:45:11'),
(7, 15, 16, 'ukm', '2026-10-25 13:58:09'),
(8, 15, 129, NULL, '2026-10-25 14:22:13');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `follows`
--

CREATE TABLE `follows` (
  `id` int NOT NULL,
  `follower_id` int NOT NULL,
  `followed_id` int NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `follows`
--

INSERT INTO `follows` (`id`, `follower_id`, `followed_id`, `created_at`) VALUES
(1, 101, 102, '2026-09-17 14:14:40'),
(2, 102, 101, '2026-09-17 14:14:40'),
(3, 101, 104, '2026-09-17 14:14:40'),
(4, 104, 101, '2026-09-17 14:14:40'),
(5, 105, 101, '2026-09-17 14:14:40'),
(6, 107, 101, '2026-09-17 14:14:40'),
(9, 16, 15, '2026-10-14 15:47:41');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `hashtags`
--

CREATE TABLE `hashtags` (
  `id` int NOT NULL,
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `usage_count` int DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `hashtags`
--

INSERT INTO `hashtags` (`id`, `name`, `usage_count`, `created_at`) VALUES
(1, 'hanoi', 1, '2026-09-17 14:32:27'),
(2, 'cafe', 1, '2026-09-17 14:32:27'),
(3, 'gym', 1, '2026-09-17 14:32:27'),
(4, 'fitness', 1, '2026-09-17 14:32:27'),
(5, 'danang', 1, '2026-09-17 14:32:27'),
(6, 'love', 1, '2026-09-17 14:32:27'),
(7, 'football', 1, '2026-09-17 14:32:27');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `interests`
--

CREATE TABLE `interests` (
  `id` int NOT NULL,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `icon` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `interests`
--

INSERT INTO `interests` (`id`, `name`, `icon`) VALUES
(1, 'Travel', '✈️'),
(2, 'Music', '🎵'),
(3, 'Sports', '⚽'),
(4, 'Food', '🍕'),
(5, 'Movies', '🎬'),
(6, 'Reading', '📚'),
(7, 'Gaming', '🎮'),
(8, 'Photography', '📸'),
(9, 'Fitness', '💪'),
(10, 'Art', '🎨'),
(11, 'Cooking', '👨‍🍳'),
(12, 'Dancing', '💃'),
(13, 'Yoga', '🧘'),
(14, 'Fashion', '👗'),
(15, 'Technology', '💻'),
(16, 'Nature', '🌳'),
(17, 'Pets', '🐶'),
(18, 'Coffee', '☕'),
(19, 'Music', 'music'),
(20, 'Travel', 'plane'),
(21, 'Movies', 'film'),
(22, 'Cooking', 'utensils'),
(23, 'Gaming', 'gamepad'),
(24, 'Sports', 'basketball-ball'),
(25, 'Reading', 'book'),
(26, 'Art', 'palette'),
(27, 'Photography', 'camera'),
(28, 'Dance', 'walking'),
(29, 'Nature', 'leaf'),
(30, 'Technology', 'laptop-code'),
(31, 'Fitness', 'dumbbell'),
(32, 'Fashion', 'tshirt'),
(33, 'Food', 'hamburger'),
(34, 'Pets', 'dog'),
(35, 'Coffee', 'coffee'),
(36, 'Yoga', 'spa');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `likes`
--

CREATE TABLE `likes` (
  `id` int NOT NULL,
  `from_user_id` int NOT NULL,
  `to_user_id` int NOT NULL,
  `liked_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `matches`
--

CREATE TABLE `matches` (
  `id` int NOT NULL,
  `user1_id` int NOT NULL,
  `user2_id` int NOT NULL,
  `matched_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `match_queue`
--

CREATE TABLE `match_queue` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `mode` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'soul or voice',
  `last_ping` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `messages`
--

CREATE TABLE `messages` (
  `id` int NOT NULL,
  `conversation_id` int NOT NULL,
  `sender_id` int NOT NULL,
  `receiver_id` int NOT NULL,
  `message_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'text' COMMENT 'text, image',
  `content` text COLLATE utf8mb4_unicode_ci,
  `media_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_read` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `reply_to` text COLLATE utf8mb4_unicode_ci,
  `reaction` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `messages`
--

INSERT INTO `messages` (`id`, `conversation_id`, `sender_id`, `receiver_id`, `message_type`, `content`, `media_url`, `is_read`, `created_at`, `reply_to`, `reaction`) VALUES
(1, 1, 15, 105, 'text', 'Chào cậu !😍', NULL, 0, '2026-10-14 15:03:12', NULL, NULL),
(2, 2, 15, 104, 'text', '1', NULL, 0, '2026-10-14 15:43:57', NULL, NULL),
(3, 1, 15, 105, 'text', '2', NULL, 0, '2026-10-14 15:44:16', NULL, NULL),
(4, 3, 15, 102, 'text', '3', NULL, 0, '2026-10-14 15:44:27', NULL, NULL),
(5, 4, 15, 101, 'text', '4', NULL, 0, '2026-10-14 15:44:45', NULL, NULL),
(6, 5, 15, 103, 'text', '5', NULL, 0, '2026-10-14 15:44:58', NULL, NULL),
(7, 6, 15, 107, 'text', '7', NULL, 0, '2026-10-14 15:45:11', NULL, NULL),
(8, 7, 16, 15, 'text', 'Chào em anh muốn làm quen !', NULL, 1, '2026-10-14 15:47:31', NULL, '❤️'),
(9, 7, 15, 16, 'text', 'Vâng em rất chào anh :))', NULL, 1, '2026-10-14 15:48:53', NULL, NULL),
(10, 7, 15, 16, 'text', 'anh tên gì hihi', NULL, 1, '2026-10-25 12:30:08', NULL, '👍'),
(11, 7, 15, 16, 'text', 'Làm thì làm nhanh đi 😜', NULL, 1, '2026-10-25 12:51:33', 'Chào em anh muốn làm quen !', NULL),
(12, 7, 15, 16, 'recalled', '[Message recalled]', NULL, 1, '2026-10-25 13:10:35', NULL, '😂'),
(13, 7, 15, 16, 'text', 'Thu hòi tin nhắn cho khỏi coi 😼', NULL, 1, '2026-10-25 13:55:44', NULL, NULL),
(14, 7, 16, 15, 'text', 'thôi khỏi coi cũng đc :))', NULL, 1, '2026-10-25 13:56:57', NULL, NULL),
(15, 7, 16, 15, 'text', 'ukm', NULL, 1, '2026-10-25 13:58:09', NULL, NULL);

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `notifications`
--

CREATE TABLE `notifications` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `sender_id` int DEFAULT NULL,
  `type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `body` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_read` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `notifications`
--

INSERT INTO `notifications` (`id`, `user_id`, `sender_id`, `type`, `title`, `body`, `is_read`, `created_at`) VALUES
(1, 16, 15, 'message', 'New Message', 'You received a new message!', 1, '2026-10-25 13:55:44'),
(2, 15, 16, 'message', 'New Message', 'You received a new message!', 1, '2026-10-25 13:56:58'),
(3, 15, 16, 'message', 'New Message', 'You received a new message!', 1, '2026-10-25 13:58:09');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `otp_codes`
--

CREATE TABLE `otp_codes` (
  `id` int NOT NULL,
  `email` varchar(255) NOT NULL,
  `otp_code` varchar(6) NOT NULL,
  `expires_at` datetime NOT NULL,
  `is_used` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Đang đổ dữ liệu cho bảng `otp_codes`
--

INSERT INTO `otp_codes` (`id`, `email`, `otp_code`, `expires_at`, `is_used`, `created_at`) VALUES
(10, 'bekajeb466@playboot.com', '184991', '2026-08-14 14:55:58', 0, '2026-08-14 14:45:58'),
(11, 'kapoyo2950@slotbeer.com', '351047', '2026-08-30 14:21:09', 0, '2026-08-30 14:11:09'),
(12, 'canakog403@robustq.com', '765505', '2026-08-30 22:21:02', 0, '2026-08-30 14:51:02'),
(13, 'canakog403@robustq.com', '104015', '2026-08-30 22:22:56', 1, '2026-08-30 14:52:56'),
(14, 'homafim948@robustq.com', '242316', '2026-09-01 10:38:26', 1, '2026-09-01 03:08:26'),
(15, 'homafim948@robustq.com', '744327', '2026-09-01 12:11:28', 1, '2026-09-01 04:41:28'),
(16, 'dilewor406@slotbeer.com', '094254', '2026-09-01 12:55:57', 1, '2026-09-01 05:25:57'),
(17, 'yesid63528@robustq.com', '631677', '2026-09-01 17:50:44', 0, '2026-09-01 10:20:44'),
(18, 'poxojo1340@slotbeer.com', '183817', '2026-09-01 19:36:31', 1, '2026-09-01 12:06:31'),
(21, 'febatax342@proguidex.com', '702154', '2026-10-15 19:53:48', 0, '2026-10-15 12:23:48'),
(22, 'vevajab925@moravita.com', '426805', '2026-10-15 20:23:38', 1, '2026-10-15 12:53:38'),
(25, 'bixovi4463@moravita.com', '868247', '2026-10-19 00:32:58', 1, '2026-10-18 17:02:58'),
(26, 'tonociy304@moravita.com', '916942', '2026-10-19 07:45:02', 1, '2026-10-19 00:15:02'),
(27, 'radaver987@moravita.com', '944004', '2026-10-20 21:40:53', 1, '2026-10-20 14:10:53');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `parties`
--

CREATE TABLE `parties` (
  `id` int NOT NULL,
  `host_id` int NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `theme` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT 'General',
  `participants_count` int DEFAULT '1',
  `is_live` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `is_private` tinyint(1) DEFAULT '0',
  `password` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `parties`
--

INSERT INTO `parties` (`id`, `host_id`, `title`, `theme`, `participants_count`, `is_live`, `created_at`, `is_private`, `password`) VALUES
(1, 15, 'Late Night Chill & Lofi Beats 🎧', '☕ Chill', 12, 1, '2026-10-25 15:22:34', 0, NULL),
(2, 16, 'Speed Dating & Voice Match 💕', '💕 Dating', 28, 1, '2026-10-25 15:22:34', 0, NULL),
(3, 101, 'Singing Contest & EDM Party 🎤', '🎵 Music', 45, 1, '2026-10-25 15:22:34', 0, NULL),
(4, 102, 'Confessions & Deep Soul Talks 💬', '☕ Chill', 18, 1, '2026-10-25 15:22:34', 0, NULL);

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `posts`
--

CREATE TABLE `posts` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `image_url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` tinyint(1) DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `posts`
--

INSERT INTO `posts` (`id`, `user_id`, `content`, `image_url`, `status`, `created_at`, `updated_at`) VALUES
(1001, 101, 'Hôm nay trời đẹp quá, có ai đi cafe với mình không? ☕️ #hanoi #cafe', NULL, 1, '2026-09-17 01:30:00', '2026-09-17 14:14:39'),
(1002, 102, 'Vừa hoàn thành buổi tập sáng, cảm thấy tràn đầy năng lượng! 💪 #gym #fitness', NULL, 1, '2026-09-17 02:15:00', '2026-09-17 14:14:39'),
(1003, 103, 'Đà Nẵng mùa này biển đẹp lắm mọi người ơi 🌊 #danang #beach', NULL, 1, '2026-09-16 13:00:00', '2026-09-17 14:14:39'),
(1005, 105, 'Nấu ăn là cách mình thư giãn sau một ngày làm việc 🍳 #cooking #home', NULL, 1, '2026-09-17 05:00:00', '2026-09-17 14:14:39'),
(1006, 107, 'Tiệc tối cuối tuần cùng hội bạn thân! 🎉 #saigon #party', NULL, 1, '2026-09-15 15:30:00', '2026-09-17 14:14:39'),
(1007, 104, 'Có ai tin vào định mệnh không? #love #soulmate', NULL, 1, '2026-09-17 07:20:00', '2026-09-17 14:14:39'),
(1011, 15, 'tìm kiếm anh trai dập cỡ này :))', NULL, 1, '2026-10-09 03:14:04', '2026-10-09 13:02:39'),
(1021, 15, 'Đây là cây quạt điều hòa cao 1m90 !', NULL, 0, '2026-10-09 08:47:16', '2026-10-09 13:02:03'),
(1022, 129, '', NULL, 1, '2026-10-20 14:12:14', '2026-10-20 14:12:14'),
(1023, 129, '', NULL, 1, '2026-10-20 14:12:47', '2026-10-20 14:12:47');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `post_comments`
--

CREATE TABLE `post_comments` (
  `id` int NOT NULL,
  `post_id` int NOT NULL,
  `user_id` int NOT NULL,
  `parent_id` int DEFAULT NULL,
  `comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `post_comments`
--

INSERT INTO `post_comments` (`id`, `post_id`, `user_id`, `parent_id`, `comment`, `created_at`) VALUES
(7, 1001, 102, NULL, 'Đi đâu thế cho mình ké với? 😉', '2026-09-17 01:35:00'),
(8, 1001, 101, NULL, 'Quán ở Hồ Tây nha bạn!', '2026-09-17 01:40:00'),
(9, 1002, 101, NULL, 'Chăm chỉ quá anh ơi 👏', '2026-09-17 02:20:00'),
(10, 1007, 105, NULL, 'Mình tin nè, quan trọng là gặp đúng người!', '2026-09-17 07:30:00');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `post_hashtags`
--

CREATE TABLE `post_hashtags` (
  `post_id` int NOT NULL,
  `hashtag_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `post_hashtags`
--

INSERT INTO `post_hashtags` (`post_id`, `hashtag_id`) VALUES
(1001, 1),
(1001, 2),
(1002, 3),
(1002, 4),
(1003, 5),
(1007, 6);

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `post_likes`
--

CREATE TABLE `post_likes` (
  `id` int NOT NULL,
  `post_id` int NOT NULL,
  `user_id` int NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `post_likes`
--

INSERT INTO `post_likes` (`id`, `post_id`, `user_id`, `created_at`) VALUES
(4, 1001, 102, '2026-09-17 14:14:40'),
(5, 1001, 104, '2026-09-17 14:14:40'),
(6, 1001, 105, '2026-09-17 14:14:40'),
(7, 1002, 101, '2026-09-17 14:14:40'),
(9, 1003, 108, '2026-09-17 14:14:40'),
(11, 1007, 101, '2026-09-17 14:14:40'),
(12, 1007, 103, '2026-09-17 14:14:40'),
(13, 1007, 105, '2026-09-17 14:14:40'),
(14, 1007, 107, '2026-09-17 14:14:40'),
(15, 1021, 15, '2026-10-09 09:28:24');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `post_photos`
--

CREATE TABLE `post_photos` (
  `id` int NOT NULL,
  `post_id` int NOT NULL,
  `photo_url` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `alignment_x` decimal(5,4) NOT NULL DEFAULT '0.0000',
  `alignment_y` decimal(5,4) NOT NULL DEFAULT '0.0000',
  `scale` decimal(4,2) NOT NULL DEFAULT '1.00'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `post_photos`
--

INSERT INTO `post_photos` (`id`, `post_id`, `photo_url`, `created_at`, `alignment_x`, `alignment_y`, `scale`) VALUES
(17, 1001, 'uploads/posts/demo_p1_1.jpg', '2026-09-17 14:14:40', 0.0000, -0.5000, 1.20),
(18, 1002, 'uploads/posts/demo_p2_1.jpg', '2026-09-17 14:14:40', 0.0000, 0.2000, 1.00),
(19, 1003, 'uploads/posts/demo_p3_1.jpg', '2026-09-17 14:14:40', 0.5000, 0.0000, 1.50),
(21, 1005, 'uploads/posts/demo_p5_1.jpg', '2026-09-17 14:14:40', 0.0000, 0.0000, 1.10),
(22, 1006, 'uploads/posts/demo_p6_1.jpg', '2026-09-17 14:14:40', 0.0000, 0.0000, 1.00),
(23, 1006, 'uploads/posts/demo_p6_2.jpg', '2026-09-17 14:14:40', 0.0000, 0.0000, 1.00),
(24, 1007, 'uploads/posts/demo_p7_1.jpg', '2026-09-17 14:14:40', 0.0000, -0.8000, 2.00),
(38, 1021, 'uploads/posts/post_15_6ac8e5cb97015_upd_0.webp', '2026-10-09 13:02:03', 0.0000, 0.0000, 1.00),
(39, 1021, 'uploads/posts/post_15_6ac8e5cb99b9e_upd_1.jpg', '2026-10-09 13:02:03', 0.0000, 0.0000, 1.00),
(40, 1021, 'uploads/posts/post_15_6ac8e5cb9ae6d_upd_2.png', '2026-10-09 13:02:03', 0.0000, 0.0000, 1.00),
(41, 1011, 'uploads/posts/post_15_6ac8e5efcd824_upd_0.jpg', '2026-10-09 13:02:39', 0.0000, 0.0000, 1.00),
(42, 1011, 'uploads/posts/post_15_6ac8e5efcf9cc_upd_1.jpg', '2026-10-09 13:02:39', 0.0000, 0.0000, 1.00),
(43, 1011, 'uploads/posts/post_15_6ac8e5efd1d85_upd_2.jpg', '2026-10-09 13:02:39', 0.0000, 0.0000, 1.00),
(44, 1011, 'uploads/posts/post_15_6ac8e5efd3290_upd_3.png', '2026-10-09 13:02:39', 0.0000, 0.0000, 1.00),
(45, 1011, 'uploads/posts/post_15_6ac8e5efd5f37_upd_4.jpg', '2026-10-09 13:02:39', 0.0000, 0.0000, 1.00),
(46, 1022, 'uploads/posts/post_129_6ad776be6a3c1_0.jpg', '2026-10-20 14:12:14', 0.0000, 0.0000, 1.00),
(47, 1023, 'uploads/posts/post_129_6ad776df244f2_0.jpg', '2026-10-20 14:12:47', 0.0000, 0.0000, 1.00);

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `reports`
--

CREATE TABLE `reports` (
  `id` int NOT NULL,
  `reporter_id` int NOT NULL,
  `target_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'post',
  `target_id` int NOT NULL,
  `reason` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `reports`
--

INSERT INTO `reports` (`id`, `reporter_id`, `target_type`, `target_id`, `reason`, `description`, `status`, `created_at`) VALUES
(1, 15, 'post', 5, 'Spam', '', 'dismissed', '2026-09-27 09:42:21');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `settings`
--

CREATE TABLE `settings` (
  `key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `value` text COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `settings`
--

INSERT INTO `settings` (`key`, `value`) VALUES
('paypal_email', 'liembaber00@gmail.com'),
('paypal_mode', 'sandbox');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `soul_matches`
--

CREATE TABLE `soul_matches` (
  `id` int NOT NULL,
  `user1_id` int NOT NULL,
  `user2_id` int NOT NULL,
  `status` int DEFAULT '0' COMMENT '0: pending/chatting, 1: liked, 2: passed, 3: mutual_matched',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `soul_matches`
--

INSERT INTO `soul_matches` (`id`, `user1_id`, `user2_id`, `status`, `created_at`) VALUES
(1, 15, 104, 2, '2026-10-11 08:47:48'),
(2, 15, 116, 1, '2026-10-11 08:49:00'),
(3, 15, 102, 2, '2026-10-11 08:50:01'),
(4, 15, 108, 2, '2026-10-11 09:30:02'),
(5, 15, 115, 2, '2026-10-11 10:52:19');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `transactions`
--

CREATE TABLE `transactions` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `amount_usd` decimal(10,2) NOT NULL,
  `coins` int NOT NULL,
  `gateway` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'PayPal',
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'completed',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `transactions`
--

INSERT INTO `transactions` (`id`, `user_id`, `amount_usd`, `coins`, `gateway`, `status`, `created_at`) VALUES
(1, 15, 4.99, 100, 'PayPal', 'completed', '2026-09-29 13:30:05'),
(2, 15, 4.99, 100, 'PayPal', 'completed', '2026-10-09 02:34:18');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `users`
--

CREATE TABLE `users` (
  `id` int NOT NULL,
  `full_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('user','admin') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'user',
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gender` enum('male','female','other') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `bio` text COLLATE utf8mb4_unicode_ci,
  `profile_photo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `location` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `latitude` decimal(10,8) DEFAULT NULL,
  `longitude` decimal(11,8) DEFAULT NULL,
  `is_verified` tinyint(1) NOT NULL DEFAULT '0',
  `email_verified` tinyint(1) NOT NULL DEFAULT '0',
  `coins` int DEFAULT '10',
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `users`
--

INSERT INTO `users` (`id`, `full_name`, `email`, `role`, `password`, `phone`, `gender`, `date_of_birth`, `bio`, `profile_photo`, `location`, `latitude`, `longitude`, `is_verified`, `email_verified`, `coins`, `is_active`, `created_at`, `updated_at`) VALUES
(15, 'dilewor406', 'dilewor406@slotbeer.com', 'user', '$2y$10$4W44WaJwuV./iTzg2B31Gev6TJRbz5sDDp2eik0st0XP8s9885giS', '0359750304', 'male', '2000-01-12', 'buy8oh89h9', 'uploads/profile_photos/profile_15_1789283211.png', 'Kim Bảng, Lê Hồ, Ninh Bình', NULL, NULL, 1, 0, 810, 1, '2026-09-01 05:25:57', '2026-10-25 16:14:17'),
(16, 'yesid63528', 'yesid63528@robustq.com', 'user', '$2y$10$1dELgT9dAW83Empi/rkGrutz/BpjinHKTKyrXdAWquOhYOXv0R7iC', '', NULL, NULL, '', 'uploads/profile_photos/profile_16_1788279528.jpg', '', NULL, NULL, 0, 0, 10, 1, '2026-09-01 10:20:44', '2026-10-25 13:57:58'),
(101, 'Linh Angel', 'linh.angel@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'female', '2002-05-20', 'Yêu màu hồng, ghét sự giả dối ✨', 'uploads/profile_photos/demo_1.jpg', 'Hà Nội', NULL, NULL, 1, 0, 50, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(102, 'Minh Tuấn', 'tuan.minh@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'male', '1998-11-12', 'Gym, Coffee and Coding ☕️💪', 'uploads/profile_photos/demo_2.jpg', 'TP. Hồ Chí Minh', NULL, NULL, 1, 0, 20, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(103, 'Khánh Vy', 'vy.khanh@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'female', '2004-01-15', 'Gen Z chính hiệu, thích đi du lịch ✈️', 'uploads/profile_photos/demo_3.jpg', 'Đà Nẵng', NULL, NULL, 0, 0, 10, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(104, 'Hoàng Long', 'long.hoang@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'male', '1995-07-08', 'Thích tìm hiểu về tâm lý học và vũ trụ 🌌', 'uploads/profile_photos/demo_4.jpg', 'Hải Phòng', NULL, NULL, 1, 0, 100, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(105, 'Thủy Tiên', 'tien.thuy@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'female', '2000-03-25', 'Tìm kiếm một mối quan hệ nghiêm túc ❤️', 'uploads/profile_photos/demo_5.jpg', 'Cần Thơ', NULL, NULL, 1, 0, 30, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(107, 'Bảo Ngọc', 'ngoc.bao@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'female', '2001-12-30', 'Work hard, play hard! 💃', 'uploads/profile_photos/demo_7.jpg', 'TP. Hồ Chí Minh', NULL, NULL, 1, 0, 45, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(108, 'Quốc Huy', 'huy.quoc@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'male', '2003-02-14', 'Nhiếp ảnh gia nghiệp dư 📸', 'uploads/profile_photos/demo_8.jpg', 'Đà Lạt', NULL, NULL, 1, 0, 10, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(113, 'Vamper Boss', 'admin@gmail.com', 'admin', '$2y$10$oWV64BK2riYgSRgCg.Vw2eTWCTlfcAG3os9mwiRS2vYfseNY8fgNu', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 0, 999, 1, '2026-09-17 17:00:47', '2026-09-27 06:11:43'),
(116, 'Liem20cm', 'yivog51484@leafflip.com', 'user', '$2y$10$SA0FlQOxfqiGOzMldbluc.FKojC/o1sMvvxBtgObwZuUvqKfiqp0m', NULL, 'male', NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, 100, 1, '2026-10-09 07:07:55', '2026-10-09 07:08:12'),
(117, 'febatax342', 'febatax342@proguidex.com', 'user', '$2y$10$ePKOTJFSerew0IyL2UJGkum59eBcPY9gobEyotQS9lw6S5m6hgQIW', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, 10, 1, '2026-10-15 12:23:48', '2026-10-15 12:23:48'),
(118, 'vevajab925', 'vevajab925@moravita.com', 'user', '$2y$10$Eg5OhS9kunuIqaAaPbe/YuU5Px7Y7YKXYgM72cCYWD5.2IRkA5ahm', NULL, 'male', '2000-01-13', 'No Biot Yet', NULL, NULL, NULL, NULL, 1, 1, 10, 1, '2026-10-15 12:53:38', '2026-10-15 12:54:50'),
(119, 'Vamper Boss', 'admin', 'admin', '$2y$10$sVauG3GQbcO20UPQjh0ZfeWe1go278qxm6oXg7sr6lJtYSypwVwKi', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 0, 999, 1, '2026-10-16 00:54:32', '2026-10-16 00:54:32'),
(127, 'bixovi4463', 'bixovi4463@moravita.com', 'user', '$2y$10$RQj9Deelm30QkKmAYxwLyOHPga44ujvPlbAR/zmJrPruHbcbUz2WS', NULL, 'male', '2000-01-02', 'No Biot Yet', 'uploads/profile_photos/profile_127_1792343078.jpg', NULL, NULL, NULL, 1, 1, 10, 1, '2026-10-18 17:02:58', '2026-10-18 17:04:38'),
(128, 'tonociy304', 'tonociy304@moravita.com', 'user', '$2y$10$jdx/oBjnwkR5BYy8M6.QTeywbPsmFrPsGDoFfP.zPYQmaFAKoAUG6', NULL, 'male', '2000-01-10', 'No Biot Yet', 'uploads/profile_photos/profile_128_1792368980.jpg', NULL, NULL, NULL, 1, 1, 10, 1, '2026-10-19 00:15:02', '2026-10-19 00:16:20'),
(129, 'radaver987', 'radaver987@moravita.com', 'user', '$2y$10$LQqNXZ.PShiLewOufI2b6.kWTdPG5LFWslT0Srk3FSOxlv9nJIXBC', NULL, 'male', '2005-01-29', '', NULL, NULL, NULL, NULL, 1, 1, 10, 1, '2026-10-20 14:10:53', '2026-10-20 14:11:50');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `user_interests`
--

CREATE TABLE `user_interests` (
  `user_id` int NOT NULL,
  `interest_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `user_photos`
--

CREATE TABLE `user_photos` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `photo_url` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_profile` tinyint(1) DEFAULT '0',
  `sort_order` int DEFAULT '0',
  `is_primary` tinyint(1) DEFAULT '0',
  `order_index` int DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `user_photos`
--

INSERT INTO `user_photos` (`id`, `user_id`, `photo_url`, `is_profile`, `sort_order`, `is_primary`, `order_index`, `created_at`) VALUES
(1, 15, 'uploads/user_photos/user_15_6a966220e0c47.jpg', 1, 0, 0, 0, '2026-09-01 05:26:56'),
(2, 15, 'uploads/user_photos/user_15_6a966231d40dd.jpg', 0, 1, 0, 0, '2026-09-01 05:27:13');

--
-- Chỉ mục cho các bảng đã đổ
--

--
-- Chỉ mục cho bảng `card_swipes`
--
ALTER TABLE `card_swipes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_swipe` (`user_id`,`target_id`);

--
-- Chỉ mục cho bảng `comment_interactions`
--
ALTER TABLE `comment_interactions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_comment_user_interaction` (`comment_id`,`user_id`),
  ADD KEY `comment_interactions_ibfk_2` (`user_id`);

--
-- Chỉ mục cho bảng `conversations`
--
ALTER TABLE `conversations`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_conv` (`user1_id`,`user2_id`);

--
-- Chỉ mục cho bảng `follows`
--
ALTER TABLE `follows`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_follow` (`follower_id`,`followed_id`),
  ADD KEY `follows_ibfk_2` (`followed_id`);

--
-- Chỉ mục cho bảng `hashtags`
--
ALTER TABLE `hashtags`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `name` (`name`);

--
-- Chỉ mục cho bảng `interests`
--
ALTER TABLE `interests`
  ADD PRIMARY KEY (`id`);

--
-- Chỉ mục cho bảng `likes`
--
ALTER TABLE `likes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_like` (`from_user_id`,`to_user_id`),
  ADD KEY `idx_to_user` (`to_user_id`);

--
-- Chỉ mục cho bảng `matches`
--
ALTER TABLE `matches`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_match` (`user1_id`,`user2_id`),
  ADD KEY `user2_id` (`user2_id`);

--
-- Chỉ mục cho bảng `match_queue`
--
ALTER TABLE `match_queue`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_queue` (`user_id`,`mode`);

--
-- Chỉ mục cho bảng `messages`
--
ALTER TABLE `messages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_conv` (`conversation_id`);

--
-- Chỉ mục cho bảng `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user` (`user_id`);

--
-- Chỉ mục cho bảng `otp_codes`
--
ALTER TABLE `otp_codes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_email` (`email`),
  ADD KEY `idx_expires` (`expires_at`),
  ADD KEY `idx_otp_email` (`email`),
  ADD KEY `idx_otp_combined` (`email`,`otp_code`,`is_used`,`expires_at`);

--
-- Chỉ mục cho bảng `parties`
--
ALTER TABLE `parties`
  ADD PRIMARY KEY (`id`);

--
-- Chỉ mục cho bảng `posts`
--
ALTER TABLE `posts`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`);

--
-- Chỉ mục cho bảng `post_comments`
--
ALTER TABLE `post_comments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `post_id` (`post_id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `post_comments_ibfk_3` (`parent_id`);

--
-- Chỉ mục cho bảng `post_hashtags`
--
ALTER TABLE `post_hashtags`
  ADD PRIMARY KEY (`post_id`,`hashtag_id`),
  ADD KEY `post_hashtags_ibfk_2` (`hashtag_id`);

--
-- Chỉ mục cho bảng `post_likes`
--
ALTER TABLE `post_likes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_post_user_like` (`post_id`,`user_id`),
  ADD KEY `user_id` (`user_id`);

--
-- Chỉ mục cho bảng `post_photos`
--
ALTER TABLE `post_photos`
  ADD PRIMARY KEY (`id`),
  ADD KEY `post_photos_ibfk_1` (`post_id`);

--
-- Chỉ mục cho bảng `reports`
--
ALTER TABLE `reports`
  ADD PRIMARY KEY (`id`);

--
-- Chỉ mục cho bảng `settings`
--
ALTER TABLE `settings`
  ADD PRIMARY KEY (`key`);

--
-- Chỉ mục cho bảng `soul_matches`
--
ALTER TABLE `soul_matches`
  ADD PRIMARY KEY (`id`);

--
-- Chỉ mục cho bảng `transactions`
--
ALTER TABLE `transactions`
  ADD PRIMARY KEY (`id`);

--
-- Chỉ mục cho bảng `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `idx_users_email` (`email`),
  ADD KEY `idx_email` (`email`),
  ADD KEY `idx_location` (`latitude`,`longitude`);

--
-- Chỉ mục cho bảng `user_interests`
--
ALTER TABLE `user_interests`
  ADD PRIMARY KEY (`user_id`,`interest_id`),
  ADD KEY `interest_id` (`interest_id`);

--
-- Chỉ mục cho bảng `user_photos`
--
ALTER TABLE `user_photos`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`);

--
-- AUTO_INCREMENT cho các bảng đã đổ
--

--
-- AUTO_INCREMENT cho bảng `card_swipes`
--
ALTER TABLE `card_swipes`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=43;

--
-- AUTO_INCREMENT cho bảng `comment_interactions`
--
ALTER TABLE `comment_interactions`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT cho bảng `conversations`
--
ALTER TABLE `conversations`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT cho bảng `follows`
--
ALTER TABLE `follows`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT cho bảng `hashtags`
--
ALTER TABLE `hashtags`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT cho bảng `interests`
--
ALTER TABLE `interests`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=37;

--
-- AUTO_INCREMENT cho bảng `likes`
--
ALTER TABLE `likes`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT cho bảng `matches`
--
ALTER TABLE `matches`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT cho bảng `match_queue`
--
ALTER TABLE `match_queue`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=47;

--
-- AUTO_INCREMENT cho bảng `messages`
--
ALTER TABLE `messages`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT cho bảng `notifications`
--
ALTER TABLE `notifications`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT cho bảng `otp_codes`
--
ALTER TABLE `otp_codes`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=28;

--
-- AUTO_INCREMENT cho bảng `parties`
--
ALTER TABLE `parties`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT cho bảng `posts`
--
ALTER TABLE `posts`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1024;

--
-- AUTO_INCREMENT cho bảng `post_comments`
--
ALTER TABLE `post_comments`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT cho bảng `post_likes`
--
ALTER TABLE `post_likes`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT cho bảng `post_photos`
--
ALTER TABLE `post_photos`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=48;

--
-- AUTO_INCREMENT cho bảng `reports`
--
ALTER TABLE `reports`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT cho bảng `soul_matches`
--
ALTER TABLE `soul_matches`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT cho bảng `transactions`
--
ALTER TABLE `transactions`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT cho bảng `users`
--
ALTER TABLE `users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=130;

--
-- AUTO_INCREMENT cho bảng `user_photos`
--
ALTER TABLE `user_photos`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- Các ràng buộc cho các bảng đã đổ
--

--
-- Các ràng buộc cho bảng `comment_interactions`
--
ALTER TABLE `comment_interactions`
  ADD CONSTRAINT `comment_interactions_ibfk_1` FOREIGN KEY (`comment_id`) REFERENCES `post_comments` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `comment_interactions_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Các ràng buộc cho bảng `follows`
--
ALTER TABLE `follows`
  ADD CONSTRAINT `follows_ibfk_1` FOREIGN KEY (`follower_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `follows_ibfk_2` FOREIGN KEY (`followed_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Các ràng buộc cho bảng `likes`
--
ALTER TABLE `likes`
  ADD CONSTRAINT `likes_ibfk_1` FOREIGN KEY (`from_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `likes_ibfk_2` FOREIGN KEY (`to_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Các ràng buộc cho bảng `matches`
--
ALTER TABLE `matches`
  ADD CONSTRAINT `matches_ibfk_1` FOREIGN KEY (`user1_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `matches_ibfk_2` FOREIGN KEY (`user2_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Các ràng buộc cho bảng `posts`
--
ALTER TABLE `posts`
  ADD CONSTRAINT `posts_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Các ràng buộc cho bảng `post_comments`
--
ALTER TABLE `post_comments`
  ADD CONSTRAINT `post_comments_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `post_comments_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `post_comments_ibfk_3` FOREIGN KEY (`parent_id`) REFERENCES `post_comments` (`id`) ON DELETE CASCADE;

--
-- Các ràng buộc cho bảng `post_hashtags`
--
ALTER TABLE `post_hashtags`
  ADD CONSTRAINT `post_hashtags_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `post_hashtags_ibfk_2` FOREIGN KEY (`hashtag_id`) REFERENCES `hashtags` (`id`) ON DELETE CASCADE;

--
-- Các ràng buộc cho bảng `post_likes`
--
ALTER TABLE `post_likes`
  ADD CONSTRAINT `post_likes_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `post_likes_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Các ràng buộc cho bảng `post_photos`
--
ALTER TABLE `post_photos`
  ADD CONSTRAINT `post_photos_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE;

--
-- Các ràng buộc cho bảng `user_interests`
--
ALTER TABLE `user_interests`
  ADD CONSTRAINT `user_interests_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `user_interests_ibfk_2` FOREIGN KEY (`interest_id`) REFERENCES `interests` (`id`) ON DELETE CASCADE;

--
-- Các ràng buộc cho bảng `user_photos`
--
ALTER TABLE `user_photos`
  ADD CONSTRAINT `user_photos_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
