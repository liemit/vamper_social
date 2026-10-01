-- VAMPER DUMMY DATA SCRIPT
-- All passwords are: password123

-- 1. INSERT 10 DIVERSE USERS
INSERT INTO `users` (`id`, `full_name`, `email`, `password`, `gender`, `date_of_birth`, `bio`, `profile_photo`, `location`, `is_verified`, `coins`) VALUES
(101, 'Linh Angel', 'linh.angel@test.com', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', 'female', '2002-05-20', 'Yêu màu hồng, ghét sự giả dối ✨', 'uploads/profile_photos/demo_1.jpg', 'Hà Nội', 1, 50),
(102, 'Minh Tuấn', 'tuan.minh@test.com', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', 'male', '1998-11-12', 'Gym, Coffee and Coding ☕️💪', 'uploads/profile_photos/demo_2.jpg', 'TP. Hồ Chí Minh', 1, 20),
(103, 'Khánh Vy', 'vy.khanh@test.com', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', 'female', '2004-01-15', 'Gen Z chính hiệu, thích đi du lịch ✈️', 'uploads/profile_photos/demo_3.jpg', 'Đà Nẵng', 0, 10),
(104, 'Hoàng Long', 'long.hoang@test.com', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', 'male', '1995-07-08', 'Thích tìm hiểu về tâm lý học và vũ trụ 🌌', 'uploads/profile_photos/demo_4.jpg', 'Hải Phòng', 1, 100),
(105, 'Thủy Tiên', 'tien.thuy@test.com', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', 'female', '2000-03-25', 'Tìm kiếm một mối quan hệ nghiêm túc ❤️', 'uploads/profile_photos/demo_5.jpg', 'Cần Thơ', 1, 30),
(106, 'Đức Anh', 'anh.duc@test.com', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', 'male', '1999-09-09', 'Chàng trai hướng nội, yêu mèo 🐈', 'uploads/profile_photos/demo_6.jpg', 'Hà Nội', 0, 15),
(107, 'Bảo Ngọc', 'ngoc.bao@test.com', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', 'female', '2001-12-30', 'Work hard, play hard! 💃', 'uploads/profile_photos/demo_7.jpg', 'TP. Hồ Chí Minh', 1, 45),
(108, 'Quốc Huy', 'huy.quoc@test.com', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', 'male', '2003-02-14', 'Nhiếp ảnh gia nghiệp dư 📸', 'uploads/profile_photos/demo_8.jpg', 'Đà Lạt', 1, 10),
(109, 'Mai Phương', 'phuong.mai@test.com', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', 'female', '1997-06-18', 'Thích nấu ăn và nghe nhạc Trịnh 🎵', 'uploads/profile_photos/demo_9.jpg', 'Nha Trang', 1, 25),
(110, 'Tiến Đạt', 'dat.tien@test.com', '$2y$10$ueHRNS.Kti/0X6p.PMkyAuap6Oksd5bH4M5XzY.G1OeOoYopjkWYG', 'male', '2000-10-10', 'Thích bóng đá và các trò chơi mạo hiểm ⚽️', 'uploads/profile_photos/demo_10.jpg', 'TP. Hồ Chí Minh', 0, 5);

-- 2. INSERT MOMENTS (POSTS)
INSERT INTO `posts` (`id`, `user_id`, `content`, `created_at`) VALUES
(1001, 101, 'Hôm nay trời đẹp quá, có ai đi cafe với mình không? ☕️ #hanoi #cafe', '2026-09-17 08:30:00'),
(1002, 102, 'Vừa hoàn thành buổi tập sáng, cảm thấy tràn đầy năng lượng! 💪 #gym #fitness', '2026-09-17 09:15:00'),
(1003, 103, 'Đà Nẵng mùa này biển đẹp lắm mọi người ơi 🌊 #danang #beach', '2026-09-16 20:00:00'),
(1004, 108, 'Góc nhỏ bình yên tại Đà Lạt 🌲 #dalat #chill', '2026-09-17 10:45:00'),
(1005, 105, 'Nấu ăn là cách mình thư giãn sau một ngày làm việc 🍳 #cooking #home', '2026-09-17 12:00:00'),
(1006, 107, 'Tiệc tối cuối tuần cùng hội bạn thân! 🎉 #saigon #party', '2026-09-15 22:30:00'),
(1007, 104, 'Có ai tin vào định mệnh không? #love #soulmate', '2026-09-17 14:20:00'),
(1008, 101, 'Mới tậu được bộ váy xinh quá 👗 #fashion #shopping', '2026-09-17 16:10:00'),
(1009, 110, 'Trận bóng hôm nay kịch tính thật sự! ⚽️ #football #winner', '2026-09-17 18:00:00'),
(1010, 109, 'Biển Nha Trang chiều hoàng hôn 🌅 #nhatrang #sunset', '2026-09-16 17:45:00');

-- 3. INSERT POST PHOTOS (WITH ALIGNMENTS & SCALES)
INSERT INTO `post_photos` (`post_id`, `photo_url`, `alignment_x`, `alignment_y`, `scale`) VALUES
(1001, 'uploads/posts/demo_p1_1.jpg', 0.0, -0.5, 1.2), -- Focused up for face
(1002, 'uploads/posts/demo_p2_1.jpg', 0.0, 0.2, 1.0),
(1003, 'uploads/posts/demo_p3_1.jpg', 0.5, 0.0, 1.5), -- Focused right for scenery
(1004, 'uploads/posts/demo_p4_1.jpg', 0.0, 0.0, 1.0),
(1005, 'uploads/posts/demo_p5_1.jpg', 0.0, 0.0, 1.1),
(1006, 'uploads/posts/demo_p6_1.jpg', 0.0, 0.0, 1.0),
(1006, 'uploads/posts/demo_p6_2.jpg', 0.0, 0.0, 1.0), -- Carousel test
(1007, 'uploads/posts/demo_p7_1.jpg', 0.0, -0.8, 2.0), -- Close up
(1008, 'uploads/posts/demo_p8_1.jpg', 0.0, 0.5, 1.0), -- Focused down for dress
(1009, 'uploads/posts/demo_p9_1.jpg', 0.0, 0.0, 1.0),
(1010, 'uploads/posts/demo_p10_1.jpg', 0.0, 0.0, 1.0);

-- 4. INSERT INTERACTIONS (LIKES & COMMENTS)
INSERT INTO `post_likes` (`post_id`, `user_id`) VALUES
(1001, 102), (1001, 104), (1001, 105),
(1002, 101), (1002, 106),
(1003, 108), (1003, 109),
(1007, 101), (1007, 103), (1007, 105), (1007, 107);

INSERT INTO `post_comments` (`post_id`, `user_id`, `comment`, `created_at`) VALUES
(1001, 102, 'Đi đâu thế cho mình ké với? 😉', '2026-09-17 08:35:00'),
(1001, 101, 'Quán ở Hồ Tây nha bạn!', '2026-09-17 08:40:00'),
(1002, 101, 'Chăm chỉ quá anh ơi 👏', '2026-09-17 09:20:00'),
(1007, 105, 'Mình tin nè, quan trọng là gặp đúng người!', '2026-09-17 14:30:00');

-- 5. INSERT FOLLOWS
INSERT INTO `follows` (`follower_id`, `followed_id`) VALUES
(101, 102), (102, 101),
(101, 104), (104, 101),
(105, 101), (107, 101),
(102, 106), (106, 102);
