<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.sql.*, java.util.UUID, java.net.URLEncoder" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    if (currentUser == null || currentUser.trim().isEmpty()) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("login.jsp");
        return;
    }

    String targetId = request.getParameter("target_id");
    if (targetId != null) targetId = targetId.trim();

    if (targetId == null || targetId.isEmpty() || targetId.equals(currentUser)) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("main.jsp");
        return;
    }

    String isPrivate = "F";
    boolean targetExists = false;

    // 타겟 유저 정보 조회  비밀계정 여부
    try {
        String usql =
            "SELECT is_private FROM users WHERE user_id = ?";
        try (PreparedStatement ps = con.prepareStatement(usql)) {
            ps.setString(1, targetId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    targetExists = true;
                    isPrivate = rs.getString("is_private");
                    if (isPrivate == null) isPrivate = "F";
                }
            }
        }
    } catch (Exception e) {
        e.printStackTrace();
    }

    if (!targetExists) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("main.jsp");
        return;
    }

    boolean alreadyFollowing = false;

    try {
        // 이미 팔로우 중인지 확인
        String chkSql =
            "SELECT 1 FROM followings " +
            "WHERE user_id = ? AND follower_id = ?";
        try (PreparedStatement ps = con.prepareStatement(chkSql)) {
            ps.setString(1, currentUser);
            ps.setString(2, targetId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) alreadyFollowing = true;
            }
        }

        boolean oldAuto = con.getAutoCommit();
        con.setAutoCommit(false);

        try {
            if (alreadyFollowing) {
                // 언팔로우  (공개/비밀 계정 공통)
                String del1 = "DELETE FROM followings WHERE user_id = ? AND follower_id = ?";
                try (PreparedStatement ps = con.prepareStatement(del1)) {
                    ps.setString(1, currentUser);
                    ps.setString(2, targetId);
                    ps.executeUpdate();
                }

                String del2 = "DELETE FROM follower WHERE user_id = ? AND follower_id = ?";
                try (PreparedStatement ps = con.prepareStatement(del2)) {
                    ps.setString(1, targetId);
                    ps.setString(2, currentUser);
                    ps.executeUpdate();
                }

                // 혹시 남아 있을지 모르는 팔로우 요청도 정리
                String delReq =
                    "DELETE FROM follow_requests " +
                    "WHERE requester_id = ? AND target_id = ?";
                try (PreparedStatement ps = con.prepareStatement(delReq)) {
                    ps.setString(1, currentUser);
                    ps.setString(2, targetId);
                    ps.executeUpdate();
                }

            } else {
                // 아직 팔로우 중이 아님
                if ("T".equals(isPrivate)) {
                    // 비밀 계정  → 팔로우 요청만 생성
                    // 이미 요청이 있는지 확인
                    boolean alreadyRequested = false;
                    String rchk =
                        "SELECT 1 FROM follow_requests " +
                        "WHERE requester_id = ? AND target_id = ?";
                    try (PreparedStatement ps = con.prepareStatement(rchk)) {
                        ps.setString(1, currentUser);
                        ps.setString(2, targetId);
                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) alreadyRequested = true;
                        }
                    }

                    if (!alreadyRequested) {
                        String rid = "frq" + UUID.randomUUID().toString().replace("-", "").substring(0, 8);
                        String rsql =
                            "INSERT INTO follow_requests (req_id, requester_id, target_id) " +
                            "VALUES (?, ?, ?)";
                        try (PreparedStatement ps = con.prepareStatement(rsql)) {
                            ps.setString(1, rid);
                            ps.setString(2, currentUser);
                            ps.setString(3, targetId);
                            ps.executeUpdate();
                        }
                    }
                    // 비밀 계정에서는 여기서 실제 followings/follower에 넣지 않음
                    // 계정주가 나중에 승인해야 진짜 팔로우가 됨

                } else {
                    // 공개 계정  → 즉시 팔로우 (기존 로직)
                    String fid1 = "fw" + UUID.randomUUID().toString().replace("-", "").substring(0, 8);
                    String fid2 = "fr" + UUID.randomUUID().toString().replace("-", "").substring(0, 8);

                    String ins1 =
                        "INSERT INTO followings (f_id, user_id, follower_id) " +
                        "VALUES (?, ?, ?)";
                    try (PreparedStatement ps = con.prepareStatement(ins1)) {
                        ps.setString(1, fid1);
                        ps.setString(2, currentUser);
                        ps.setString(3, targetId);
                        ps.executeUpdate();
                    }

                    String ins2 =
                        "INSERT INTO follower (f_id, user_id, follower_id) " +
                        "VALUES (?, ?, ?)";
                    try (PreparedStatement ps = con.prepareStatement(ins2)) {
                        ps.setString(1, fid2);
                        ps.setString(2, currentUser); // 내가 팔로우한 사람  (팔로워 목록 기준 user_id)
                        ps.setString(3, targetId);    // 내가 팔로우하는 대상
                        // 만약 기존 설계에서 user_id = 대상, follower_id = 나 였다면 이 부분은
                        // ps.setString(2, targetId);
                        // ps.setString(3, currentUser);
                        // 로 맞춰줘야 함  (실제 테이블 구조에 따라)
                        ps.executeUpdate();
                    }
                }
            }

            con.commit();
            con.setAutoCommit(oldAuto);
        } catch (Exception e) {
            con.rollback();
            con.setAutoCommit(true);
            throw e;
        }

    } catch (Exception e) {
        e.printStackTrace();
    } finally {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
    }

    // 원래 보던 페이지로 되돌아가기
    String referer = request.getHeader("Referer");
    if (referer == null || referer.length() == 0) {
        referer = "profile.jsp?user=" + URLEncoder.encode(targetId, "UTF-8");
    }
    response.sendRedirect(referer);
%>
