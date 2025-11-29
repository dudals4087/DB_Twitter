<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");
    
    // 1. 로그인 체크
    String currentUser = (String) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    try {
        // 2. DB 업데이트: 해당 유저의 paid 컬럼을 'T'로 변경 (구독 처리)
        String sql = "UPDATE users SET paid = 'T' WHERE user_id = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, currentUser);
            ps.executeUpdate();
        }

        // 3. [중요] 세션 정보 즉시 업데이트 
        // (로그아웃 안 해도 바로 파란 딱지가 보이게 하기 위함)
        session.setAttribute("currentUserPaid", true);

        // 4. 성공 알림 후 설정 페이지로 이동
%>
        <script>
            alert("구독이 완료되었습니다! 프리미엄 혜택이 적용됩니다.");
            location.href = "settings.jsp";
        </script>
<%
    } catch (Exception e) {
        e.printStackTrace();
%>
        <script>
            alert("결제 처리 중 오류가 발생했습니다.");
            history.back();
        </script>
<%
    } finally {
        if (con != null) try { con.close(); } catch(Exception e) {}
    }
%>