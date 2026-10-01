-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Máy chủ: localhost:3306
-- Thời gian đã tạo: Th9 27, 2026 lúc 08:20 AM
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
(7, 102, 106, '2026-09-17 14:14:40'),
(8, 106, 102, '2026-09-17 14:14:40');

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
-- Cấu trúc bảng cho bảng `otp_codes`
--

CREATE TABLE `otp_codes` (
  `id` int NOT NULL,
  `email` varchar(255) NOT NULL,
  `otp_code` varchar(6) NOT NULL,
  `expires_at` datetime NOT NULL,
  `is_used` tinyint(1) DEFAULT '0',
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
(18, 'poxojo1340@slotbeer.com', '183817', '2026-09-01 19:36:31', 1, '2026-09-01 12:06:31');

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
(4, 15, 'Hello World !', NULL, 1, '2026-09-13 18:11:43', '2026-09-17 09:30:01'),
(5, 15, '110cm :)))', NULL, 1, '2026-09-17 09:28:28', '2026-09-17 09:28:43'),
(1001, 101, 'Hôm nay trời đẹp quá, có ai đi cafe với mình không? ☕️ #hanoi #cafe', NULL, 1, '2026-09-17 01:30:00', '2026-09-17 14:14:39'),
(1002, 102, 'Vừa hoàn thành buổi tập sáng, cảm thấy tràn đầy năng lượng! 💪 #gym #fitness', NULL, 1, '2026-09-17 02:15:00', '2026-09-17 14:14:39'),
(1003, 103, 'Đà Nẵng mùa này biển đẹp lắm mọi người ơi 🌊 #danang #beach', NULL, 1, '2026-09-16 13:00:00', '2026-09-17 14:14:39'),
(1004, 108, 'Góc nhỏ bình yên tại Đà Lạt 🌲 #dalat #chill', NULL, 1, '2026-09-17 03:45:00', '2026-09-17 14:14:39'),
(1005, 105, 'Nấu ăn là cách mình thư giãn sau một ngày làm việc 🍳 #cooking #home', NULL, 1, '2026-09-17 05:00:00', '2026-09-17 14:14:39'),
(1006, 107, 'Tiệc tối cuối tuần cùng hội bạn thân! 🎉 #saigon #party', NULL, 1, '2026-09-15 15:30:00', '2026-09-17 14:14:39'),
(1007, 104, 'Có ai tin vào định mệnh không? #love #soulmate', NULL, 1, '2026-09-17 07:20:00', '2026-09-17 14:14:39'),
(1008, 101, 'Mới tậu được bộ váy xinh quá 👗 #fashion #shopping', NULL, 1, '2026-09-17 09:10:00', '2026-09-17 14:14:39');

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
(4, 5, 15, NULL, 'Yohhhhh', '2026-09-17 09:29:03'),
(5, 5, 15, NULL, '.', '2026-09-17 13:26:33'),
(6, 4, 15, NULL, 'mê vc ấy :))', '2026-09-17 13:27:42'),
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
(8, 1002, 106, '2026-09-17 14:14:40'),
(9, 1003, 108, '2026-09-17 14:14:40'),
(11, 1007, 101, '2026-09-17 14:14:40'),
(12, 1007, 103, '2026-09-17 14:14:40'),
(13, 1007, 105, '2026-09-17 14:14:40'),
(14, 1007, 107, '2026-09-17 14:14:40');

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
(1, 4, 'uploads/posts/post_15_6aa6e75f37614_0.jpg', '2026-09-13 18:11:43', 0.0000, 0.0000, 1.00),
(2, 4, 'uploads/posts/post_15_6aa6e75f3f8d0_1.jpg', '2026-09-13 18:11:43', 0.0000, 0.0000, 1.00),
(3, 4, 'uploads/posts/post_15_6aa6e75f40c50_2.jpg', '2026-09-13 18:11:43', 0.0000, 0.0000, 1.00),
(4, 4, 'uploads/posts/post_15_6aa6e75f41a3b_3.jpg', '2026-09-13 18:11:43', 0.0000, 0.0000, 1.00),
(5, 4, 'uploads/posts/post_15_6aa6e75f42e41_4.jpg', '2026-09-13 18:11:43', 0.0000, 0.0000, 1.00),
(6, 4, 'uploads/posts/post_15_6aa6e75f44639_5.jpg', '2026-09-13 18:11:43', 0.0000, 0.0000, 1.00),
(7, 4, 'uploads/posts/post_15_6aa6e7b85b93e_upd_0.jpg', '2026-09-13 18:13:12', 0.0000, 0.0000, 1.00),
(8, 4, 'uploads/posts/post_15_6aa6e7b85d953_upd_1.jpg', '2026-09-13 18:13:12', 0.0000, 0.0000, 1.00),
(9, 4, 'uploads/posts/post_15_6aa6e7b85e6f9_upd_2.jpg', '2026-09-13 18:13:12', 0.0000, 0.0000, 1.00),
(10, 4, 'uploads/posts/post_15_6aa6e7b85f444_upd_3.jpg', '2026-09-13 18:13:12', 0.0000, 0.0000, 1.00),
(11, 4, 'uploads/posts/post_15_6aa6e7b860705_upd_4.jpg', '2026-09-13 18:13:12', 0.0000, 0.0000, 1.00),
(12, 4, 'uploads/posts/post_15_6aa6e7b8612ca_upd_5.jpg', '2026-09-13 18:13:12', 0.0000, 0.0000, 1.00),
(13, 4, 'uploads/posts/post_15_6aa6e7b862081_upd_6.webp', '2026-09-13 18:13:12', 0.0000, 0.0000, 1.00),
(14, 4, 'uploads/posts/post_15_6aa6e7b862cd4_upd_7.jpg', '2026-09-13 18:13:12', 0.0000, 0.0000, 1.00),
(15, 4, 'uploads/posts/post_15_6aa6e7b863a5b_upd_8.png', '2026-09-13 18:13:12', -0.7965, 0.3711, 1.35),
(16, 5, 'uploads/posts/post_15_6aabb2bcd86d8_0.jpg', '2026-09-17 09:28:28', -0.7100, -0.0500, 1.00),
(17, 1001, 'uploads/posts/demo_p1_1.jpg', '2026-09-17 14:14:40', 0.0000, -0.5000, 1.20),
(18, 1002, 'uploads/posts/demo_p2_1.jpg', '2026-09-17 14:14:40', 0.0000, 0.2000, 1.00),
(19, 1003, 'uploads/posts/demo_p3_1.jpg', '2026-09-17 14:14:40', 0.5000, 0.0000, 1.50),
(20, 1004, 'uploads/posts/demo_p4_1.jpg', '2026-09-17 14:14:40', 0.0000, 0.0000, 1.00),
(21, 1005, 'uploads/posts/demo_p5_1.jpg', '2026-09-17 14:14:40', 0.0000, 0.0000, 1.10),
(22, 1006, 'uploads/posts/demo_p6_1.jpg', '2026-09-17 14:14:40', 0.0000, 0.0000, 1.00),
(23, 1006, 'uploads/posts/demo_p6_2.jpg', '2026-09-17 14:14:40', 0.0000, 0.0000, 1.00),
(24, 1007, 'uploads/posts/demo_p7_1.jpg', '2026-09-17 14:14:40', 0.0000, -0.8000, 2.00),
(25, 1008, 'uploads/posts/demo_p8_1.jpg', '2026-09-17 14:14:40', 0.0000, 0.5000, 1.00);

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
  `is_verified` tinyint(1) DEFAULT '0',
  `coins` int DEFAULT '10',
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `users`
--

INSERT INTO `users` (`id`, `full_name`, `email`, `role`, `password`, `phone`, `gender`, `date_of_birth`, `bio`, `profile_photo`, `location`, `latitude`, `longitude`, `is_verified`, `coins`, `is_active`, `created_at`, `updated_at`) VALUES
(14, 'homafim', 'homafim948@robustq.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', '', 'male', '2002-01-14', '1m83', 'uploads/profile_photos/profile_14_1788279438.png', 'Kim Boi, Phu Tho', NULL, NULL, 1, 10, 1, '2026-09-01 04:41:28', '2026-09-02 06:14:51'),
(15, 'dilewor406', 'dilewor406@slotbeer.com', 'user', '$2y$10$4W44WaJwuV./iTzg2B31Gev6TJRbz5sDDp2eik0st0XP8s9885giS', '0359750304', 'male', '2000-01-12', 'buy8oh89h9', 'uploads/profile_photos/profile_15_1789283211.png', 'Kim Bảng, Lê Hồ, Ninh Bình', NULL, NULL, 1, 10, 1, '2026-09-01 05:25:57', '2026-09-27 07:13:10'),
(16, 'yesid63528', 'yesid63528@robustq.com', 'user', '$2y$10$1dELgT9dAW83Empi/rkGrutz/BpjinHKTKyrXdAWquOhYOXv0R7iC', '', NULL, NULL, '', 'uploads/profile_photos/profile_16_1788279528.jpg', '', NULL, NULL, 0, 10, 1, '2026-09-01 10:20:44', '2026-09-27 08:16:38'),
(101, 'Linh Angel', 'linh.angel@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'female', '2002-05-20', 'Yêu màu hồng, ghét sự giả dối ✨', 'uploads/profile_photos/demo_1.jpg', 'Hà Nội', NULL, NULL, 1, 50, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(102, 'Minh Tuấn', 'tuan.minh@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'male', '1998-11-12', 'Gym, Coffee and Coding ☕️💪', 'uploads/profile_photos/demo_2.jpg', 'TP. Hồ Chí Minh', NULL, NULL, 1, 20, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(103, 'Khánh Vy', 'vy.khanh@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'female', '2004-01-15', 'Gen Z chính hiệu, thích đi du lịch ✈️', 'uploads/profile_photos/demo_3.jpg', 'Đà Nẵng', NULL, NULL, 0, 10, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(104, 'Hoàng Long', 'long.hoang@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'male', '1995-07-08', 'Thích tìm hiểu về tâm lý học và vũ trụ 🌌', 'uploads/profile_photos/demo_4.jpg', 'Hải Phòng', NULL, NULL, 1, 100, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(105, 'Thủy Tiên', 'tien.thuy@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'female', '2000-03-25', 'Tìm kiếm một mối quan hệ nghiêm túc ❤️', 'uploads/profile_photos/demo_5.jpg', 'Cần Thơ', NULL, NULL, 1, 30, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(106, 'Đức Anh', 'anh.duc@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'male', '1999-09-09', 'Chàng trai hướng nội, yêu mèo 🐈', 'uploads/profile_photos/demo_6.jpg', 'Hà Nội', NULL, NULL, 0, 15, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(107, 'Bảo Ngọc', 'ngoc.bao@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'female', '2001-12-30', 'Work hard, play hard! 💃', 'uploads/profile_photos/demo_7.jpg', 'TP. Hồ Chí Minh', NULL, NULL, 1, 45, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(108, 'Quốc Huy', 'huy.quoc@test.com', 'user', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', NULL, 'male', '2003-02-14', 'Nhiếp ảnh gia nghiệp dư 📸', 'uploads/profile_photos/demo_8.jpg', 'Đà Lạt', NULL, NULL, 1, 10, 1, '2026-09-17 14:14:39', '2026-09-17 14:14:39'),
(113, 'Vamper Boss', 'admin@gmail.com', 'admin', '$2y$10$oWV64BK2riYgSRgCg.Vw2eTWCTlfcAG3os9mwiRS2vYfseNY8fgNu', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 999, 1, '2026-09-17 17:00:47', '2026-09-27 06:11:43');

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
-- Chỉ mục cho bảng `comment_interactions`
--
ALTER TABLE `comment_interactions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_comment_user_interaction` (`comment_id`,`user_id`),
  ADD KEY `comment_interactions_ibfk_2` (`user_id`);

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
-- Chỉ mục cho bảng `otp_codes`
--
ALTER TABLE `otp_codes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_email` (`email`),
  ADD KEY `idx_expires` (`expires_at`);

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
-- Chỉ mục cho bảng `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`),
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
-- AUTO_INCREMENT cho bảng `comment_interactions`
--
ALTER TABLE `comment_interactions`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT cho bảng `follows`
--
ALTER TABLE `follows`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

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
-- AUTO_INCREMENT cho bảng `otp_codes`
--
ALTER TABLE `otp_codes`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT cho bảng `posts`
--
ALTER TABLE `posts`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1011;

--
-- AUTO_INCREMENT cho bảng `post_comments`
--
ALTER TABLE `post_comments`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT cho bảng `post_likes`
--
ALTER TABLE `post_likes`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT cho bảng `post_photos`
--
ALTER TABLE `post_photos`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=28;

--
-- AUTO_INCREMENT cho bảng `users`
--
ALTER TABLE `users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=114;

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
