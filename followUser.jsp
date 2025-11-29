<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.util.UUID" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    String targetId = request.getParameter("target_id");

    // 1. 로그인 체크
    if (currentUser == null) {
        out.println("<script>alert('로그인이 필요합니다.'); location.href='login.jsp';</script>");
        return;
    }

    // 2. 돌아갈 페이지 주소 정리
    String referer = request.getHeader("Referer");
    if (referer == null) referer = "main.jsp";
    if (referer.contains("#")) referer = referer.substring(0, referer.indexOf("#"));

    if (targetId == null || targetId.isEmpty() || currentUser.equals(targetId)) {
        response.sendRedirect(referer);
        return;
    }

    try {
        // [1단계] 상대방 비공개 여부 확인
        boolean isPrivate = false;
        String userCheckSql = "SELECT is_private FROM users WHERE user_id = ?";
        try (PreparedStatement ps = con.prepareStatement(userCheckSql)) {
            ps.setString(1, targetId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    String p = rs.getString("is_private");
                    if ("T".equals(p)) isPrivate = true;
                }
            }
        }

        // [2단계] 현재 상태 확인
        boolean isFollowing = false;
        boolean isRequested = false;

        String fCheck = "SELECT 1 FROM followings WHERE user_id = ? AND follower_id = ?";
        try (PreparedStatement ps = con.prepareStatement(fCheck)) {
            ps.setString(1, targetId);
            ps.setString(2, currentUser);
            try (ResultSet rs = ps.executeQuery()) { if (rs.next()) isFollowing = true; }
        }

        String rCheck = "SELECT 1 FROM follow_requests WHERE target_id = ? AND requester_id = ?";
        try (PreparedStatement ps = con.prepareStatement(rCheck)) {
            ps.setString(1, targetId);
            ps.setString(2, currentUser);
            try (ResultSet rs = ps.executeQuery()) { if (rs.next()) isRequested = true; }
        }

        // [3단계] 로직 실행
        if (isFollowing) {
            // [A] 언팔로우 (삭제)
            String delSql = "DELETE FROM followings WHERE user_id = ? AND follower_id = ?";
            try (PreparedStatement ps = con.prepareStatement(delSql)) {
                ps.setString(1, targetId);
                ps.setString(2, currentUser);
                ps.executeUpdate();
            }
        } 
        else if (isRequested) {
            // [B] 요청 취소 (삭제)
            String delReq = "DELETE FROM follow_requests WHERE target_id = ? AND requester_id = ?";
            try (PreparedStatement ps = con.prepareStatement(delReq)) {
                ps.setString(1, targetId);
                ps.setString(2, currentUser);
                ps.executeUpdate();
            }
        } 
        else {
            // [C] 새로 연결
            if (isPrivate) {
                // [C-1] 비공개 계정 -> 요청 (날짜 제거함)
                String reqId = "r" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
                String insReq = "INSERT INTO follow_requests (req_id, target_id, requester_id) VALUES (?, ?, ?)";
                try (PreparedStatement ps = con.prepareStatement(insReq)) {
                    ps.setString(1, reqId);
                    ps.setString(2, targetId);
                    ps.setString(3, currentUser);
                    ps.executeUpdate();
                }
            } else {
                // [C-2] 공개 계정 -> 즉시 팔로우 (날짜 제거함)
                String followId = "f" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
                String insFollow = "INSERT INTO followings (f_id, user_id, follower_id) VALUES (?, ?, ?)";
                try (PreparedStatement ps = con.prepareStatement(insFollow)) {
                    ps.setString(1, followId);
                    ps.setString(2, targetId);
                    ps.setString(3, currentUser);
                    ps.executeUpdate();
                }
            }
        }

    } catch (Exception e) {
        e.printStackTrace();
        String errorMsg = e.getMessage();
        if (errorMsg == null) errorMsg = "Unknown Error";
        errorMsg = errorMsg.replace("'", "").replace("\"", "").replace("\n", " ");
%>
    <script>
        alert("처리 중 오류 발생: <%= errorMsg %>");
        history.back();
    </script>
<%
        return;
    } finally {
        if (con != null) try { con.close(); } catch(Exception e) {}
    }

    response.sendRedirect(referer);
%>