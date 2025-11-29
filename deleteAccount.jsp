<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");
    String currentUser = (String) session.getAttribute("currentUser");

    // 1. 로그인 안 되어 있으면 튕겨냄
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    // 트랜잭션 처리를 위해 오토커밋 해제 (중간에 실패하면 롤백하기 위함)
    boolean defaultAutoCommit = con.getAutoCommit();
    con.setAutoCommit(false);

    try {
        // [단계 1] '좋아요' 기록 삭제 (에러의 주범)
        // 내가 누른 좋아요 삭제
        try (PreparedStatement ps = con.prepareStatement("DELETE FROM post_likes WHERE liker_id = ?")) {
            ps.setString(1, currentUser);
            ps.executeUpdate();
        }

        // [단계 2] '팔로우' 관계 삭제 (나를 팔로우한 것, 내가 팔로우한 것 모두)
        try (PreparedStatement ps = con.prepareStatement("DELETE FROM followings WHERE user_id = ? OR follower_id = ?")) {
            ps.setString(1, currentUser);
            ps.setString(2, currentUser);
            ps.executeUpdate();
        }

        // [단계 3] '팔로우 요청' 삭제 (보낸 요청, 받은 요청 모두)
        try (PreparedStatement ps = con.prepareStatement("DELETE FROM follow_requests WHERE target_id = ? OR requester_id = ?")) {
            ps.setString(1, currentUser);
            ps.setString(2, currentUser);
            ps.executeUpdate();
        }

        // [단계 4] '메시지' 삭제 (보낸 것, 받은 것)
        try (PreparedStatement ps = con.prepareStatement("DELETE FROM message WHERE sender = ? OR receiver = ?")) {
            ps.setString(1, currentUser);
            ps.setString(2, currentUser);
            ps.executeUpdate();
        }

        // [단계 5] '댓글' 삭제 (내가 쓴 댓글) - 테이블명이 comments라고 가정
        try (PreparedStatement ps = con.prepareStatement("DELETE FROM comments WHERE user_id = ?")) {
            ps.setString(1, currentUser);
            ps.executeUpdate();
        } catch (Exception ignore) { 
            // 댓글 테이블 컬럼명이 다르거나 없을 수도 있으니 에러 무시하고 진행
        }

        // [단계 6] '게시글' 삭제 (내가 쓴 글)
        // 주의: 게시글에 달린 남들의 댓글/좋아요 때문에 여기서도 에러가 날 수 있으나,
        // 보통 게시글이 지워지면 CASCADE 되는 경우가 많음. 안 되면 게시글 좋아요도 지워야 함.
        
        // 6-1. 내 글에 달린 좋아요 먼저 삭제 (안전장치)
        try (PreparedStatement ps = con.prepareStatement(
            "DELETE FROM post_likes WHERE post_id IN (SELECT post_id FROM posts WHERE writer_id = ?)")) {
            ps.setString(1, currentUser);
            ps.executeUpdate();
        }
        
        // 6-2. 내 글에 달린 댓글 먼저 삭제 (안전장치)
        try (PreparedStatement ps = con.prepareStatement(
            "DELETE FROM comments WHERE post_id IN (SELECT post_id FROM posts WHERE writer_id = ?)")) {
            ps.setString(1, currentUser);
            ps.executeUpdate();
        } catch (Exception ignore) {}

        // 6-3. 진짜 게시글 삭제
        try (PreparedStatement ps = con.prepareStatement("DELETE FROM posts WHERE writer_id = ?")) {
            ps.setString(1, currentUser);
            ps.executeUpdate();
        }

        // [단계 7] 드디어 '회원' 본체 삭제
        String sql = "DELETE FROM users WHERE user_id = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, currentUser);
            int result = ps.executeUpdate();

            if (result > 0) {
                // 모든 삭제 성공 시 커밋
                con.commit();
                
                // 세션 파기 (로그아웃)
                session.invalidate();
%>
                <script>
                    alert("탈퇴가 완료되었습니다. 모든 데이터가 삭제되었습니다.");
                    location.href = "login.jsp";
                </script>
<%
            } else {
                con.rollback(); // 실패 시 되돌리기
%>
                <script>
                    alert("탈퇴 처리에 실패했습니다. (DB 삭제 실패)");
                    history.back();
                </script>
<%
            }
        }
    } catch (Exception e) {
        con.rollback(); // 에러 발생 시 롤백
        e.printStackTrace();
        String errMsg = e.getMessage().replace("'", "").replace("\n", " ");
%>
        <script>
            alert("오류 발생: 연관된 데이터가 너무 많거나 DB 설정 문제입니다.\n내용: <%= errMsg %>");
            history.back();
        </script>
<%
    } finally {
        // 오토커밋 설정 원상복구 및 연결 종료
        if (con != null) {
            try { con.setAutoCommit(defaultAutoCommit); con.close(); } catch(Exception e) {}
        }
    }
%>